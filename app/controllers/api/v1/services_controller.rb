module Api
  module V1
    class ServicesController < BaseController
      def index
        pag   = pagination_params
        scope = Registries::Entities::Service.all

        scope = scope.where("name ILIKE ?", "%#{params[:name]}%") if params[:name].present?
        scope = scope.where(active: params[:active])               if params.key?(:active)

        total   = scope.count
        records = scope.order(:name)
                       .offset((pag[:page] - 1) * pag[:per_page])
                       .limit(pag[:per_page])

        set_pagination_headers(total, pag[:page], pag[:per_page])
        render_success(records)
      end

      def show
        service = Registries::Entities::Service.find(params[:id])
        render_success(service)
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Service not found", status: :not_found)
      end

      def create
        service = Registries::Entities::Service.new(service_params)

        if service.save
          render_created(service)
        else
          render_error(code: "validation_error", message: "Validation failed",
                       details: service.errors.full_messages, status: :unprocessable_entity)
        end
      end

      def update
        service = Registries::Entities::Service.find(params[:id])

        if service.update(service_params)
          render_success(service)
        else
          render_error(code: "validation_error", message: "Validation failed",
                       details: service.errors.full_messages, status: :unprocessable_entity)
        end
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Service not found", status: :not_found)
      end

      def destroy
        service = Registries::Entities::Service.find(params[:id])
        service.update!(deleted_at: Time.current)
        render_no_content
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Service not found", status: :not_found)
      end

      private

      def service_params
        params.permit(:name, :description, :base_price_cents, :estimated_duration_minutes, :active)
      end
    end
  end
end
