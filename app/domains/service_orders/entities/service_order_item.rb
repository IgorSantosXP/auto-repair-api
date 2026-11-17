module ServiceOrders
  module Entities
    # `part_id` is the identifier of a part in the Execution Service catalog.
    # Name and price are snapshotted when the order is opened, so the order
    # never needs to read another service's database.
    class ServiceOrderItem < ApplicationRecord
      self.table_name = "service_order_items"

      belongs_to :service_order, class_name: "ServiceOrders::Entities::ServiceOrder"
      belongs_to :service, class_name: "Registries::Entities::Service", optional: true

      validates :name,             presence: true
      validates :quantity,         presence: true, numericality: { only_integer: true, greater_than: 0 }
      validates :unit_price_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :total_cents,      presence: true

      validate :exactly_one_reference

      before_validation :calculate_total

      def kind
        service_id.present? ? "service" : "part"
      end

      def reference_id
        (service_id || part_id).to_s
      end

      def item_name
        name
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
