module Inventory
  module Entities
    class StockMovement < ApplicationRecord
      self.table_name = "stock_movements"

      TYPES = %w[inbound outbound adjustment_in adjustment_out].freeze

      belongs_to :part,             class_name: "Inventory::Entities::Part"
      belongs_to :performed_by_user, class_name: "Identity::Entities::User", optional: true

      validates :movement_type, presence: true, inclusion: { in: TYPES }
      validates :quantity,      presence: true, numericality: { only_integer: true, greater_than: 0 }

      def credit?
        movement_type.in?(%w[inbound adjustment_in])
      end

      def signed_quantity
        credit? ? quantity : -quantity
      end
    end
  end
end
