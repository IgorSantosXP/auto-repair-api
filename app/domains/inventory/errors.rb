module Inventory
  module Errors
    class NotFound          < StandardError; end
    class InsufficientStock < StandardError
      def initialize(part_name, available, requested)
        super("Insufficient stock for '#{part_name}': available #{available}, requested #{requested}")
      end
    end
  end
end
