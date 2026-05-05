module ServiceOrders
  module ValueObjects
    class OrderStatus
      ALL = %w[received in_diagnosis awaiting_approval approved in_execution finished delivered].freeze

      attr_reader :value

      def initialize(value)
        @value = value.to_s
      end

      def valid?
        ALL.include?(value)
      end

      def terminal?
        value == "delivered"
      end

      def to_s
        value
      end
    end
  end
end
