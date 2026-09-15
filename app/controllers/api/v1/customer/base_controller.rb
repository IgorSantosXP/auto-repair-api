module Api
  module V1
    module Customer
      class BaseController < ApplicationController
        before_action :authenticate_customer!

        private

        def authenticate_customer!
          token = bearer_token
          raise JWT::DecodeError, "Missing token" if token.blank?

          payload = Identity::Services::JwtEncoder.decode(
            token,
            audience: Identity::Services::JwtEncoder::CUSTOMER_AUDIENCE
          )

          @current_customer = Registries::Entities::Customer.find(payload["sub"])
        rescue JWT::DecodeError, JWT::InvalidAudError, JWT::InvalidIssuerError, ActiveRecord::RecordNotFound
          render_error(
            code: "unauthorized",
            message: "Invalid or expired token. Authenticate with your CPF first.",
            status: :unauthorized
          )
        end

        def bearer_token
          request.headers["Authorization"]&.split(" ")&.last
        end

        def current_customer
          @current_customer
        end

        def authorize_order!(order)
          return if order.customer_id == current_customer.id

          render_error(
            code: "forbidden",
            message: "This service order belongs to another customer",
            status: :forbidden
          )
        end
      end
    end
  end
end
