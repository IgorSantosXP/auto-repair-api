module ServiceOrders
  module UseCases
    class ApproveOrder
      def self.call(uuid:, token:)
        ActiveRecord::Base.transaction do
          order = Entities::ServiceOrder.find_by!(uuid: uuid)

          unless order.status == "awaiting_approval"
            return Result.failure(errors: ["Order is not awaiting approval"])
          end

          unless Services::ApprovalTokenGenerator.valid?(
            token, order.approval_token_digest, order.approval_token_expires_at
          )
            return Result.failure(errors: ["Invalid or expired approval token"])
          end

          order.update!(
            status:                    "approved",
            approval_token_digest:     nil,
            approval_token_expires_at: nil
          )

          Entities::ServiceOrderStatusChange.create!(
            service_order_id: order.id,
            from_status:      "awaiting_approval",
            to_status:        "approved",
            event:            "approve",
            performed_by:     "customer"
          )

          Rails.logger.info("[ServiceOrder] #{uuid} approved by customer")
          Result.success(payload: order.reload)
        end
      rescue ActiveRecord::RecordNotFound
        Result.failure(errors: ["Service order not found"])
      end
    end
  end
end
