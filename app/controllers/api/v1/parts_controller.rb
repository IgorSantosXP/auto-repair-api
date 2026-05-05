module Api
  module V1
    class PartsController < BaseController
      def index
        pag   = pagination_params
        scope = Inventory::Entities::Part.all

        scope = scope.where("name ILIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where("sku ILIKE ?",  "%#{params[:sku]}%")  if params[:sku].present?
        scope = scope.where(active: params[:active])               if params.key?(:active)

        total   = scope.count
        records = scope.order(:name)
                       .offset((pag[:page] - 1) * pag[:per_page])
                       .limit(pag[:per_page])

        set_pagination_headers(total, pag[:page], pag[:per_page])
        render_success(records)
      end

      def show
        part = Inventory::Entities::Part.find(params[:id])
        render_success(part)
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Part not found", status: :not_found)
      end

      def create
        part = Inventory::Entities::Part.new(part_params)

        if part.save
          render_created(part)
        else
          render_error(code: "validation_error", message: "Validation failed",
                       details: part.errors.full_messages, status: :unprocessable_entity)
        end
      end

      def update
        part = Inventory::Entities::Part.find(params[:id])

        if part.update(part_params)
          render_success(part)
        else
          render_error(code: "validation_error", message: "Validation failed",
                       details: part.errors.full_messages, status: :unprocessable_entity)
        end
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Part not found", status: :not_found)
      end

      def destroy
        part = Inventory::Entities::Part.find(params[:id])
        part.update!(deleted_at: Time.current)
        render_no_content
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Part not found", status: :not_found)
      end

      def stock
        part    = Inventory::Entities::Part.find(params[:id])
        balance = Inventory::Services::StockBalanceCalculator.balance_for(part.id)
        render_success({ part_id: part.id, balance: balance })
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Part not found", status: :not_found)
      end

      private

      def part_params
        params.permit(:sku, :name, :description, :unit_price_cents, :active)
      end
    end
  end
end
