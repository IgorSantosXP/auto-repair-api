module Api
  module V1
    class StockMovementsController < BaseController
      def index
        pag  = pagination_params
        part = Inventory::Entities::Part.find(params[:part_id])

        scope   = part.stock_movements.order(created_at: :desc)
        total   = scope.count
        records = scope.offset((pag[:page] - 1) * pag[:per_page]).limit(pag[:per_page])

        set_pagination_headers(total, pag[:page], pag[:per_page])
        render_success(records)
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Part not found", status: :not_found)
      end

      def create
        result = Inventory::UseCases::RegisterMovement.call(
          part_id:       params[:part_id],
          movement_type: movement_params[:movement_type],
          quantity:      movement_params[:quantity],
          reason:        movement_params[:reason],
          performed_by:  current_user
        )

        render_result(result, on_success: :created)
      end

      private

      def movement_params
        params.permit(:movement_type, :quantity, :reason)
      end
    end
  end
end
