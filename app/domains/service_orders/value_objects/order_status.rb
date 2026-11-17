module ServiceOrders
  module ValueObjects
    class OrderStatus
      ALL = %w[
        received awaiting_approval awaiting_payment approved
        in_diagnosis in_execution finished delivered cancelled
      ].freeze

      TERMINAL = %w[delivered cancelled].freeze

      attr_reader :value

      def initialize(value)
        @value = value.to_s
      end

      def valid?
        ALL.include?(value)
      end

      def terminal?
        TERMINAL.include?(value)
      end

      def to_s
        value
      end
    end
  end
end
