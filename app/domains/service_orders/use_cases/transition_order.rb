module ServiceOrders
  module UseCases
    class TransitionOrder
      def self.call(order_id, event:, performed_by:)
        result = transition(order_id, event: event, performed_by: performed_by)

        if result.success?
          Services::CustomerNotifier.status_changed(
            result.payload[:order],
            approval_link:  result.payload[:approval_link],
            rejection_link: result.payload[:rejection_link]
          )
        end

        result
      end

      private_class_method def self.transition(order_id, event:, performed_by:)
        ActiveRecord::Base.transaction do
          order = Entities::ServiceOrder.find(order_id)
          next_status = Services::StateMachine.transition(order.status, event)
          entered_current_status_at = current_status_started_at(order)

          if next_status.nil?
            valid = Services::StateMachine.valid_events_for(order.status)
            Telemetry.order_processing_failed(stage: "transition", reason: "invalid_event")
            return Result.failure(errors: [
              "Cannot '#{event}' from '#{order.status}'. Valid events: #{valid.join(', ')}"
            ])
          end

          if event == "send_for_approval"
            token_data = Services::ApprovalTokenGenerator.generate
            order.approval_token_digest     = token_data[:digest]
            order.approval_token_expires_at = token_data[:expires_at]
          end

          order.execution_started_at = Time.current if next_status == "in_execution"
          order.finished_at          = Time.current if next_status == "finished"

          if next_status == "in_execution"
            reservation = Inventory::UseCases::ReserveForOrder.call(
              order_items:      order.items,
              service_order_id: order.id,
              performed_by:     performed_by
            )
            if reservation.failure?
              Telemetry.order_processing_failed(stage: "stock_reservation", reason: "insufficient_stock")
              Telemetry.integration_error(integration: "inventory", reason: "insufficient_stock")
              return Result.failure(errors: reservation.errors)
            end

            order.items.update_all(executed: true)
          end

          order.status = next_status
          order.save!

          Entities::ServiceOrderStatusChange.create!(
            service_order_id:     order.id,
            from_status:          order.status_before_last_save,
            to_status:            next_status,
            event:                event,
            performed_by_user_id: performed_by.id,
            performed_by:         "admin"
          )

          Telemetry.status_transition(
            from:             order.status_before_last_save,
            to:               next_status,
            event:            event,
            duration_seconds: Time.current - entered_current_status_at
          )

          payload = { order: order.reload }
          if event == "send_for_approval"
            payload[:approval_link]  = build_customer_link(order, "approve", token_data[:plain])
            payload[:rejection_link] = build_customer_link(order, "reject",  token_data[:plain])
          end

          Rails.logger.info("[ServiceOrder] Transition #{order.uuid}: #{order.status_before_last_save} -> #{next_status} by user #{performed_by.id}")
          if event == "send_for_approval"
            Rails.logger.info("[ServiceOrder] Approval link for #{order.uuid}: #{payload[:approval_link]}")
          end

          Result.success(payload: payload)
        end
      rescue ActiveRecord::RecordNotFound
        Telemetry.order_processing_failed(stage: "transition", reason: "not_found")
        Result.failure(errors: ["Service order not found"])
      rescue ActiveRecord::RecordInvalid => e
        Telemetry.order_processing_failed(stage: "transition", reason: "invalid_record")
        Result.failure(errors: e.record.errors.full_messages)
      end

      private_class_method def self.current_status_started_at(order)
        Entities::ServiceOrderStatusChange
          .where(service_order_id: order.id)
          .maximum(:created_at) || order.created_at
      end

      private_class_method def self.build_customer_link(order, action, plain_token)
        base_url = ENV.fetch("APP_BASE_URL", "http://localhost:3000")
        "#{base_url}/api/v1/customer/service_orders/#{order.uuid}/#{action}?token=#{plain_token}"
      end
    end
  end
end
