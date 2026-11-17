module ServiceOrders
  module UseCases
    class DeliverOrder
      def self.call(order_id, performed_by:)
        ActiveRecord::Base.transaction do
          order = Entities::ServiceOrder.lock.find(order_id)
          Services::OrderTransitioner.apply!(order, "deliver", performed_by: "admin", user: performed_by)
          Result.success(payload: order.reload)
        end
      rescue ActiveRecord::RecordNotFound
        Result.failure(errors: ["Service order not found"], status: :not_found)
      rescue Errors::InvalidTransition => e
        Telemetry.order_processing_failed(stage: "transition", reason: "invalid_event")
        Result.failure(errors: [e.message])
      end
    end
  end
end
