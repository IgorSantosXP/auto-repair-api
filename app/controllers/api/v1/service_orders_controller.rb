module Api
  module V1
    class ServiceOrdersController < BaseController
      def index
        pag   = pagination_params
        scope = ServiceOrders::Entities::ServiceOrder
                  .includes(:customer, :vehicle, :items)

        scope = scope.where(status:      params[:status])      if params[:status].present?
        scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
        scope = scope.where(vehicle_id:  params[:vehicle_id])  if params[:vehicle_id].present?

        if params[:from].present?
          scope = scope.where("service_orders.created_at >= ?", Date.parse(params[:from]).beginning_of_day)
        end
        if params[:to].present?
          scope = scope.where("service_orders.created_at <= ?", Date.parse(params[:to]).end_of_day)
        end

        total   = scope.count
        records = scope.order(created_at: :desc)
                       .offset((pag[:page] - 1) * pag[:per_page])
                       .limit(pag[:per_page])

        set_pagination_headers(total, pag[:page], pag[:per_page])
        render_success(records)
      rescue Date::Error
        render_error(code: "invalid_date", message: "Invalid date format. Use YYYY-MM-DD.", status: :bad_request)
      end

      def show
        order = ServiceOrders::Entities::ServiceOrder
                  .includes(:customer, :vehicle, :items, :status_changes)
                  .find(params[:id])
        render_success(order)
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Service order not found", status: :not_found)
      end

      def create
        result = ServiceOrders::UseCases::CreateOrder.call(order_params, performed_by: current_user)
        render_result(result, on_success: :created)
      end

      def update
        result = ServiceOrders::UseCases::UpdateOrder.call(
          params[:id], order_update_params, performed_by: current_user
        )
        render_result(result)
      end

      def transitions
        result = ServiceOrders::UseCases::TransitionOrder.call(
          params[:id],
          event:        params[:event],
          performed_by: current_user
        )

        if result.success?
          render_success(result.payload)
        else
          render_error(
            code:    "transition_error",
            message: result.errors.first,
            details: result.errors,
            status:  :unprocessable_entity
          )
        end
      end

      private

      def order_params
        params.permit(
          :customer_id, :vehicle_id, :diagnosis_notes,
          items: [:service_id, :part_id, :quantity, :unit_price_cents]
        )
      end

      def order_update_params
        params.permit(
          :diagnosis_notes,
          items: [:service_id, :part_id, :quantity, :unit_price_cents]
        )
      end
    end
  end
end
