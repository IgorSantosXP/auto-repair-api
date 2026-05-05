module Api
  module V1
    class VehiclesController < BaseController
      def index
        pag   = pagination_params
        scope = Registries::Entities::Vehicle.includes(:customer)

        scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
        scope = scope.where("license_plate ILIKE ?", "%#{params[:license_plate]}%") if params[:license_plate].present?
        scope = scope.where("brand ILIKE ?", "%#{params[:brand]}%") if params[:brand].present?

        total   = scope.count
        records = scope.order(created_at: :desc)
                       .offset((pag[:page] - 1) * pag[:per_page])
                       .limit(pag[:per_page])

        set_pagination_headers(total, pag[:page], pag[:per_page])
        render_success(records)
      end

      def show
        vehicle = Registries::Entities::Vehicle.includes(:customer).find(params[:id])
        render_success(vehicle)
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Vehicle not found", status: :not_found)
      end

      def create
        vehicle = Registries::Entities::Vehicle.new(vehicle_params)

        if vehicle.save
          render_created(vehicle)
        else
          render_error(code: "validation_error", message: "Validation failed",
                       details: vehicle.errors.full_messages, status: :unprocessable_entity)
        end
      end

      def update
        vehicle = Registries::Entities::Vehicle.find(params[:id])

        if vehicle.update(vehicle_params)
          render_success(vehicle)
        else
          render_error(code: "validation_error", message: "Validation failed",
                       details: vehicle.errors.full_messages, status: :unprocessable_entity)
        end
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Vehicle not found", status: :not_found)
      end

      def destroy
        vehicle = Registries::Entities::Vehicle.find(params[:id])
        vehicle.update!(deleted_at: Time.current)
        render_no_content
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Vehicle not found", status: :not_found)
      end

      private

      def vehicle_params
        params.permit(:customer_id, :license_plate, :brand, :model, :year)
      end
    end
  end
end
