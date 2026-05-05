module ServiceOrders
  module Entities
    class ServiceOrder < ApplicationRecord
      self.table_name = "service_orders"

      belongs_to :customer, class_name: "Registries::Entities::Customer"
      belongs_to :vehicle,  class_name: "Registries::Entities::Vehicle"

      has_many :items,          class_name: "ServiceOrders::Entities::ServiceOrderItem",
               foreign_key: :service_order_id, dependent: :destroy
      has_many :status_changes, class_name: "ServiceOrders::Entities::ServiceOrderStatusChange",
               foreign_key: :service_order_id, dependent: :destroy

      validates :uuid,        presence: true, uniqueness: true
      validates :customer_id, presence: true
      validates :vehicle_id,  presence: true
      validates :status,      presence: true, inclusion: { in: ValueObjects::OrderStatus::ALL }

      before_validation :assign_uuid, on: :create

      def as_json(options = {})
        super(options.merge(
          except: %i[approval_token_digest],
          include: { items: { methods: [] } }
        )).merge("available_events" => Services::StateMachine.valid_events_for(status))
      end

      private

      def assign_uuid
        self.uuid ||= SecureRandom.uuid
      end
    end
  end
end
