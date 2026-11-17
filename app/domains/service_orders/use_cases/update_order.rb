module ServiceOrders
  module UseCases
    # Once the saga has requested the budget the items are owned by the
    # budget in Billing, so only the notes can still change here.
    class UpdateOrder
      def self.call(order_id, params, performed_by:)
        order = Entities::ServiceOrder.find(order_id)

        if ValueObjects::OrderStatus.new(order.status).terminal?
          return Result.failure(errors: ["Order cannot be edited in status '#{order.status}'"])
        end
        if params.key?(:items)
          return Result.failure(errors: ["Items cannot be changed after the budget was requested"])
        end

        order.update!(diagnosis_notes: params[:diagnosis_notes]) if params.key?(:diagnosis_notes)
        Rails.logger.info("[ServiceOrder] #{order.uuid} updated by user #{performed_by.id}")
        Result.success(payload: order.reload)
      rescue ActiveRecord::RecordNotFound
        Result.failure(errors: ["Service order not found"])
      rescue ActiveRecord::RecordInvalid => e
        Result.failure(errors: e.record.errors.full_messages)
      end
    end
  end
end
