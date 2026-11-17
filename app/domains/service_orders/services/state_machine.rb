module ServiceOrders
  module Services
    # Order lifecycle. Most transitions are driven by the saga orchestrator when
    # Billing and Execution report progress; only `deliver` is triggered by an
    # admin through the API.
    class StateMachine
      TRANSITIONS = {
        "received"          => { "budget_generated"  => "awaiting_approval",
                                 "cancel"            => "cancelled" },
        "awaiting_approval" => { "budget_approved"   => "awaiting_payment",
                                 "cancel"            => "cancelled" },
        "awaiting_payment"  => { "payment_confirmed" => "approved",
                                 "cancel"            => "cancelled" },
        "approved"          => { "start_diagnosis"   => "in_diagnosis",
                                 "cancel"            => "cancelled" },
        "in_diagnosis"      => { "start_repair"      => "in_execution" },
        "in_execution"      => { "finish"            => "finished" },
        "finished"          => { "deliver"           => "delivered" }
      }.freeze

      ADMIN_EVENTS = %w[deliver].freeze

      def self.transition(current_status, event)
        TRANSITIONS.dig(current_status, event)
      end

      def self.valid_events_for(status)
        (TRANSITIONS[status] || {}).keys
      end

      def self.admin_events_for(status)
        valid_events_for(status) & ADMIN_EVENTS
      end

      def self.valid_transition?(current_status, event)
        !transition(current_status, event).nil?
      end
    end
  end
end
