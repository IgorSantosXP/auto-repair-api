module ServiceOrders
  module Queries
    class ListOrdersQuery
      STATUS_PRIORITY = %w[in_execution approved awaiting_approval in_diagnosis received].freeze
      HIDDEN_STATUSES = %w[finished delivered].freeze

      def self.call(status: nil, customer_id: nil, vehicle_id: nil, from: nil, to: nil)
        scope = Entities::ServiceOrder.includes(:customer, :vehicle, :items)

        scope = filter_status(scope, status)
        scope = scope.where(customer_id: customer_id) if customer_id.present?
        scope = scope.where(vehicle_id: vehicle_id)   if vehicle_id.present?
        scope = scope.where("service_orders.created_at >= ?", from.beginning_of_day) if from
        scope = scope.where("service_orders.created_at <= ?", to.end_of_day)         if to

        scope.order(status_priority_sql).order(created_at: :asc)
      end

      private_class_method def self.filter_status(scope, status)
        return scope.where.not(status: HIDDEN_STATUSES) if status.blank?

        scope.where(status: status)
      end

      private_class_method def self.status_priority_sql
        cases = STATUS_PRIORITY.each_with_index.map { |status, index| "WHEN '#{status}' THEN #{index}" }
        Arel.sql("CASE service_orders.status #{cases.join(' ')} ELSE #{STATUS_PRIORITY.size} END")
      end
    end
  end
end
