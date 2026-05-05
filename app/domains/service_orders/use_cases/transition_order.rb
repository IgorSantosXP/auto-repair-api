module ServiceOrders
  module UseCases
    class TransitionOrder
      def self.call(order_id, event:, performed_by:)
        ActiveRecord::Base.transaction do
          order = Entities::ServiceOrder.find(order_id)
          next_status = Services::StateMachine.transition(order.status, event)

          if next_status.nil?
            valid = Services::StateMachine.valid_events_for(order.status)
            return Result.failure(errors: [
              "Cannot '#{event}' from '#{order.status}'. Valid events: #{valid.join(', ')}"
            ])
          end

          if event == "send_for_approval"
            token_data = Services::ApprovalTokenGenerator.generate
            order.approval_token_digest     = token_data[:digest]
            order.approval_token_expires_at = token_data[:expires_at]
          end

          order.execution_started_at = Time.current if next_status == "in_execution"
          order.finished_at          = Time.current if next_status == "finished"

          if next_status == "in_execution"
            reservation = Inventory::UseCases::ReserveForOrder.call(
              order_items:      order.items,
              service_order_id: order.id,
              performed_by:     performed_by
            )
            return Result.failure(errors: reservation.errors) if reservation.failure?

            order.items.update_all(executed: true)
          end

          order.status = next_status
          order.save!

          Entities::ServiceOrderStatusChange.create!(
            service_order_id:     order.id,
            from_status:          order.status_before_last_save,
            to_status:            next_status,
            event:                event,
            performed_by_user_id: performed_by.id,
            performed_by:         "admin"
          )

          payload = { order: order.reload }
          payload[:approval_link] = build_approval_link(order, token_data[:plain]) if event == "send_for_approval"

          Rails.logger.info("[ServiceOrder] Transition #{order.uuid}: #{order.status_before_last_save} -> #{next_status} by user #{performed_by.id}")
          if event == "send_for_approval"
            Rails.logger.info("[ServiceOrder] Approval link for #{order.uuid}: /api/v1/customer/service_orders/#{order.uuid}/approve?token=#{token_data[:plain]}")
          end

          Result.success(payload: payload)
        end
      rescue ActiveRecord::RecordNotFound
        Result.failure(errors: ["Service order not found"])
      rescue ActiveRecord::RecordInvalid => e
        Result.failure(errors: e.record.errors.full_messages)
      end

      private_class_method def self.build_approval_link(order, plain_token)
        "/api/v1/customer/service_orders/#{order.uuid}/approve?token=#{plain_token}"
      end
    end
  end
end
