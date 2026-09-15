module Api
  module V1
    module Customer
      class ServiceOrdersController < BaseController
        def index
          orders = ServiceOrders::Entities::ServiceOrder
                     .includes(:vehicle, :items, :status_changes)
                     .where(customer_id: current_customer.id)
                     .order(created_at: :desc)

          render_success(orders.map { |order| public_view(order) })
        end

        def show
          order = ServiceOrders::Entities::ServiceOrder
                    .includes(:customer, :vehicle, :items, :status_changes)
                    .find_by!(uuid: params[:uuid])

          return if authorize_order!(order)

          render_success(public_view(order))
        rescue ActiveRecord::RecordNotFound
          render_error(code: "not_found", message: "Service order not found", status: :not_found)
        end

        def approve
          result = ServiceOrders::UseCases::ApproveOrder.call(
            uuid:  params[:uuid],
            token: params[:token]
          )

          if result.success?
            render_success({ message: "Order approved successfully", status: result.payload.status })
          else
            render_error(code: "approval_failed", message: result.errors.first, status: :unprocessable_entity)
          end
        end

        def reject
          result = ServiceOrders::UseCases::RejectOrder.call(
            uuid:  params[:uuid],
            token: params[:token]
          )

          if result.success?
            render_success({ message: "Order rejected. Your vehicle will be available for pickup.", status: result.payload.status })
          else
            render_error(code: "rejection_failed", message: result.errors.first, status: :unprocessable_entity)
          end
        end

        private

        def authenticate_customer!
          return if signed_link_request?

          super
        end

        def signed_link_request?
          params[:token].present? && %w[approve reject].include?(action_name)
        end

        def public_view(order)
          {
            uuid:        order.uuid,
            status:      order.status,
            total_cents: order.total_cents,
            created_at:  order.created_at,
            vehicle: {
              license_plate: order.vehicle.license_plate,
              brand:         order.vehicle.brand,
              model:         order.vehicle.model,
              year:          order.vehicle.year
            },
            items: order.items.map { |item|
              {
                name:            item.item_name,
                quantity:        item.quantity,
                unit_price_cents: item.unit_price_cents,
                total_cents:     item.total_cents,
                executed:        item.executed
              }
            },
            history: order.status_changes.order(:created_at).map { |sc|
              {
                from:       sc.from_status,
                to:         sc.to_status,
                event:      sc.event,
                changed_at: sc.created_at
              }
            }
          }
        end
      end
    end
  end
end
