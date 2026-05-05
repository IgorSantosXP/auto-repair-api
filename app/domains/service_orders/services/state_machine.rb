module ServiceOrders
  module Services
    class StateMachine
      TRANSITIONS = {
        "received"          => { "start_diagnosis"   => "in_diagnosis" },
        "in_diagnosis"      => { "send_for_approval" => "awaiting_approval" },
        "awaiting_approval" => { "approve"           => "approved",
                                 "reject"            => "finished",
                                 "send_for_approval" => "awaiting_approval" },
        "approved"          => { "start_execution"   => "in_execution" },
        "in_execution"      => { "finalize"          => "finished" },
        "finished"          => { "deliver"           => "delivered" }
      }.freeze

      def self.transition(current_status, event)
        next_status = TRANSITIONS.dig(current_status, event)
        return nil if next_status.nil?

        next_status
      end

      def self.valid_events_for(status)
        (TRANSITIONS[status] || {}).keys
      end

      def self.valid_transition?(current_status, event)
        TRANSITIONS.dig(current_status, event) != nil
      end
    end
  end
end
