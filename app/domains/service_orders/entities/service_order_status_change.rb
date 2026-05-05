module ServiceOrders
  module Entities
    class ServiceOrderStatusChange < ApplicationRecord
      self.table_name = "service_order_status_changes"

      belongs_to :service_order,     class_name: "ServiceOrders::Entities::ServiceOrder"
      belongs_to :performed_by_user, class_name: "Identity::Entities::User", optional: true

      validates :to_status,    presence: true
      validates :event,        presence: true
      validates :performed_by, presence: true, inclusion: { in: %w[admin customer] }
    end
  end
end
