module ServiceOrders
  module Services
    # Applies a state machine event to an order, recording the history entry
    # and the duration metric. Must run inside the caller's transaction; the
    # customer e-mail goes out only after that transaction commits.
    class OrderTransitioner
      def self.apply!(order, event, performed_by: "system", user: nil, notes: nil)
        next_status = StateMachine.transition(order.status, event)
        if next_status.nil?
          valid = StateMachine.valid_events_for(order.status)
          raise Errors::InvalidTransition,
                "Cannot '#{event}' from '#{order.status}'. Valid events: #{valid.join(', ').presence || 'none'}"
        end

        from_status = order.status
        entered_at  = order.status_changes.maximum(:created_at) || order.created_at

        order.execution_started_at = Time.current if next_status == "in_execution"
        order.finished_at          = Time.current if next_status == "finished"
        order.update!(status: next_status)

        Entities::ServiceOrderStatusChange.create!(
          service_order_id:     order.id,
          from_status:          from_status,
          to_status:            next_status,
          event:                event,
          notes:                notes,
          performed_by:         performed_by,
          performed_by_user_id: user&.id
        )

        Telemetry.status_transition(
          from: from_status, to: next_status, event: event,
          duration_seconds: Time.current - entered_at
        )

        ActiveRecord.after_all_transactions_commit { CustomerNotifier.status_changed(order) }
        order
      end
    end
  end
end
