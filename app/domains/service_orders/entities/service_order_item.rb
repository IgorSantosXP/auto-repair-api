module ServiceOrders
  module Entities
    class ServiceOrderItem < ApplicationRecord
      self.table_name = "service_order_items"

      belongs_to :service_order, class_name: "ServiceOrders::Entities::ServiceOrder"
      belongs_to :service, class_name: "Registries::Entities::Service",   optional: true
      belongs_to :part,    class_name: "Inventory::Entities::Part",    optional: true

      validates :quantity,         presence: true, numericality: { only_integer: true, greater_than: 0 }
      validates :unit_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :total_cents,      presence: true

      validate :exactly_one_reference

      before_validation :calculate_total

      def item_name
        service&.name || part&.name
      end

      private

      def calculate_total
        self.total_cents = quantity.to_i * unit_price_cents.to_i if quantity && unit_price_cents
      end

      def exactly_one_reference
        if service_id.present? && part_id.present?
          errors.add(:base, "Item must reference either a service or a part, not both")
        elsif service_id.blank? && part_id.blank?
          errors.add(:base, "Item must reference either a service or a part")
        end
      end
    end
  end
end
