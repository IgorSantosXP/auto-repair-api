module Inventory
  module Entities
    class Part < ApplicationRecord
      self.table_name = "parts"

      has_many :stock_movements, class_name: "Inventory::Entities::StockMovement",
               foreign_key: :part_id, dependent: :destroy

      validates :sku,              presence: true
      validates :name,             presence: true
      validates :unit_price_cents, presence: true,
                                   numericality: { only_integer: true, greater_than_or_equal_to: 0 }

      default_scope { where(deleted_at: nil) }

      def as_json(*)
        super(except: %i[deleted_at])
      end
    end
  end
end
