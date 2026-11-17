module ServiceOrders
  module Orchestration
    # Orchestrated saga for a service order. The OS Service is the single
    # coordinator: it reacts to events from Billing and Execution, moves the
    # order and the saga state forward and issues the next command (or the
    # compensating one) through the transactional outbox.
    #
    #   received --generate_budget--> Billing
    #   budget_generated  -> awaiting_approval
    #   budget_approved   -> awaiting_payment
    #   payment_confirmed -> approved --execution.start--> Execution
    #   diagnosis/repair/finished -> in_diagnosis / in_execution / finished
    #
    # Compensations:
    #   execution.failed  -> billing.refund_payment -> payment_refunded -> cancelled
    #   payment_failed    -> billing.cancel_budget  -> budget_cancelled -> cancelled
    class ServiceOrderSaga
      # Raised when an event arrives before the one it depends on (SNS/SQS do
      # not guarantee ordering). The message stays on the queue and is retried.
      class OutOfOrder < StandardError; end

      EVENT_HANDLERS = {
        "billing.budget_generated"         => :on_budget_generated,
        "billing.budget_generation_failed" => :on_budget_generation_failed,
        "billing.budget_approved"          => :on_budget_approved,
        "billing.budget_rejected"          => :on_budget_rejected,
        "billing.payment_confirmed"        => :on_payment_confirmed,
        "billing.payment_failed"           => :on_payment_failed,
        "billing.budget_cancelled"         => :on_budget_cancelled,
        "billing.payment_refunded"         => :on_payment_refunded,
        "billing.refund_failed"            => :on_refund_failed,
        "execution.queued"                 => :on_execution_queued,
        "execution.failed"                 => :on_execution_failed,
        "execution.diagnosis_started"      => :on_diagnosis_started,
        "execution.repair_started"         => :on_repair_started,
        "execution.finished"               => :on_execution_finished
      }.freeze

      def self.start(order)
        saga = Entities::Saga.create!(service_order: order, state: "budget_requested")
        new(saga).send_command("billing.generate_budget", "billing", Commands.generate_budget(order))
        Telemetry.saga_started
        Messaging.logger.info("Saga started", saga_id: saga.uuid, correlation_id: saga.uuid,
                                              service_order_uuid: order.uuid)
        saga
      end

      def self.handle(envelope)
        handler = EVENT_HANDLERS.fetch(envelope.type)

        ActiveRecord::Base.transaction do
          saga = Entities::Saga.lock.find_by(uuid: envelope.saga_id)
          if saga.nil?
            Messaging.logger.warn("Event for unknown saga ignored", envelope.log_context)
            next false
          end

          new(saga).process(envelope, handler)
        end
      end

      attr_reader :saga, :order

      def initialize(saga)
        @saga  = saga
        @order = saga.service_order
      end

      def process(envelope, handler)
        from_state = saga.state
        applied    = send(handler, envelope.payload)
        record_step("received", envelope, from_state)

        unless applied
          Messaging.logger.warn("Event ignored in current saga state",
                                envelope.log_context.merge(saga_state: from_state))
        end

        applied
      end

      def send_command(type, destination, payload)
        envelope = Messaging::Envelope.command(
          type, destination: destination, payload: payload,
          saga_id: saga.uuid, service_order_uuid: order.uuid
        )
        Messaging::Outbox.enqueue(envelope)
        record_step("sent", envelope, saga.state)
        envelope
      end

      private

      # --- Billing ---------------------------------------------------------

      def on_budget_generated(payload)
        guard("budget_requested") do
          saga.budget_id = payload["budget_id"]
          move_to("awaiting_approval")
          transition_order("budget_generated", notes: "Orçamento #{payload['budget_id']} gerado")
        end
      end

      def on_budget_generation_failed(payload)
        guard("budget_requested") do
          fail_saga("budget_generation_failed: #{payload['reason']}")
          transition_order("cancel", notes: "Falha ao gerar orçamento: #{payload['reason']}")
        end
      end

      def on_budget_approved(payload)
        guard("awaiting_approval") do
          saga.payment_url = payload["payment_url"]
          move_to("awaiting_payment")
          transition_order("budget_approved", notes: "Orçamento aprovado pelo cliente")
        end
      end

      def on_budget_rejected(payload)
        guard("awaiting_approval") do
          fail_saga("budget_rejected")
          transition_order("cancel", notes: "Orçamento recusado pelo cliente. #{payload['reason']}".strip)
        end
      end

      def on_payment_confirmed(payload)
        guard("awaiting_payment") do
          saga.payment_id = payload["payment_id"]
          move_to("execution_requested")
          transition_order("payment_confirmed", notes: "Pagamento #{payload['payment_id']} confirmado")
          send_command("execution.start", "execution", Commands.start_execution(order))
        end
      end

      def on_payment_failed(payload)
        guard("awaiting_payment") do
          compensate("payment_failed: #{payload['reason']}")
          send_command("billing.cancel_budget", "billing", { "reason" => "payment_failed" })
        end
      end

      def on_budget_cancelled(_payload)
        guard("compensating") do
          finish_compensation
        end
      end

      def on_payment_refunded(payload)
        guard("compensating") do
          finish_compensation(notes: "Pagamento estornado (#{payload['refund_id']})")
        end
      end

      def on_refund_failed(payload)
        guard("compensating") do
          saga.failure_reason = [saga.failure_reason, "refund_failed: #{payload['reason']}"].compact.join(" | ")
          saga.completed_at   = Time.current
          move_to("compensation_failed")
          transition_order("cancel", notes: "Estorno falhou, requer ação manual: #{payload['reason']}")
          Telemetry.saga_compensation_failed(reason: payload["reason"])
          Messaging.logger.error("Saga compensation failed, manual refund required",
                                 saga_id: saga.uuid, correlation_id: saga.uuid,
                                 service_order_uuid: order.uuid, reason: payload["reason"])
        end
      end

      # --- Execution -------------------------------------------------------

      def on_execution_queued(_payload)
        guard("execution_requested") { move_to("in_execution") }
      end

      def on_execution_failed(payload)
        guard("execution_requested") do
          compensate("execution_failed: #{payload['reason']}")
          send_command("billing.refund_payment", "billing", { "reason" => "execution_failed: #{payload['reason']}" })
        end
      end

      def on_diagnosis_started(payload)
        guard("execution_requested", "in_execution") do
          move_to("in_execution")
          transition_order("start_diagnosis", notes: payload["notes"])
        end
      end

      def on_repair_started(payload)
        guard("execution_requested", "in_execution") do
          raise OutOfOrder, "repair_started before diagnosis_started" if order.status == "approved"

          move_to("in_execution")
          transition_order("start_repair", notes: payload["notes"])
        end
      end

      def on_execution_finished(payload)
        guard("execution_requested", "in_execution") do
          raise OutOfOrder, "finished before repair_started" if %w[approved in_diagnosis].include?(order.status)

          saga.completed_at = Time.current
          move_to("completed")
          transition_order("finish", notes: payload["notes"])
          Telemetry.saga_completed(duration_seconds: saga.completed_at - saga.created_at)
        end
      end

      # --- helpers ---------------------------------------------------------

      def guard(*expected_states)
        return false unless expected_states.include?(saga.state)

        yield
        true
      end

      def move_to(state)
        saga.state = state
        saga.save!
      end

      def compensate(reason)
        saga.failure_reason = reason
        move_to("compensating")
        Telemetry.saga_compensating(reason: reason)
      end

      def finish_compensation(notes: nil)
        saga.completed_at = Time.current
        move_to("compensated")
        transition_order("cancel", notes: ["Saga compensada: #{saga.failure_reason}", notes].compact.join(". "))
        Telemetry.saga_compensated(reason: saga.failure_reason)
      end

      def fail_saga(reason)
        saga.failure_reason = reason
        saga.completed_at   = Time.current
        move_to("failed")
        Telemetry.saga_failed(reason: reason)
      end

      def transition_order(event, notes: nil)
        Services::OrderTransitioner.apply!(order, event, performed_by: "system", notes: notes)
      end

      def record_step(direction, envelope, from_state)
        saga.steps.create!(
          direction:    direction,
          message_type: envelope.type,
          message_id:   envelope.message_id,
          from_state:   from_state,
          to_state:     saga.state,
          payload:      envelope.payload
        )
        Telemetry.saga_step(type: envelope.type, direction: direction)
      end
    end
  end
end
