module Reports
  module Queries
    class AverageExecutionTimeQuery
      def self.call(from: nil, to: nil)
        scope = ServiceOrders::Entities::ServiceOrder
                  .where.not(execution_started_at: nil)
                  .where.not(finished_at: nil)
                  .where("finished_at > execution_started_at")

        scope = scope.where("execution_started_at >= ?", from.beginning_of_day) if from
        scope = scope.where("finished_at <= ?", to.end_of_day)                  if to

        total   = scope.count
        avg_sql = scope.average("EXTRACT(EPOCH FROM (finished_at - execution_started_at))")
        avg_seconds = avg_sql ? avg_sql.to_f.round(2) : nil

        {
          total_orders:        total,
          average_seconds:     avg_seconds,
          average_hours:       avg_seconds ? (avg_seconds / 3600).round(2) : nil,
          period: { from: from, to: to }
        }
      end
    end
  end
end
