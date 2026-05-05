module Api
  module V1
    class CustomersController < BaseController
      def index
        pag   = pagination_params
        scope = Registries::Entities::Customer.all

        scope = scope.where("name ILIKE ?", "%#{params[:name]}%")     if params[:name].present?
        scope = scope.where(kind: params[:kind])                       if params[:kind].present?
        scope = scope.where("document LIKE ?", "%#{params[:document]}%") if params[:document].present?

        total   = scope.count
        records = scope.order(created_at: :desc)
                       .offset((pag[:page] - 1) * pag[:per_page])
                       .limit(pag[:per_page])

        set_pagination_headers(total, pag[:page], pag[:per_page])
        render_success(records)
      end

      def show
        customer = Registries::Entities::Customer.find(params[:id])
        render_success(customer)
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Customer not found", status: :not_found)
      end

      def create
        customer = Registries::Entities::Customer.new(customer_params)

        if customer.save
          render_created(customer)
        else
          render_error(code: "validation_error", message: "Validation failed",
                       details: customer.errors.full_messages, status: :unprocessable_entity)
        end
      end

      def update
        customer = Registries::Entities::Customer.find(params[:id])

        if customer.update(customer_params)
          render_success(customer)
        else
          render_error(code: "validation_error", message: "Validation failed",
                       details: customer.errors.full_messages, status: :unprocessable_entity)
        end
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Customer not found", status: :not_found)
      end

      def destroy
        customer = Registries::Entities::Customer.find(params[:id])
        customer.update!(deleted_at: Time.current)
        render_no_content
      rescue ActiveRecord::RecordNotFound
        render_error(code: "not_found", message: "Customer not found", status: :not_found)
      end

      private

      def customer_params
        params.permit(:kind, :document, :name, :email, :phone).tap do |p|
          p[:document] = p[:document].to_s.gsub(/\D/, "") if p[:document].present?
        end
      end
    end
  end
end
