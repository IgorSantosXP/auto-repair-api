module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_admin!

      private

      def authenticate_admin!
        token = bearer_token
        raise JWT::DecodeError, "Missing token" if token.blank?

        payload = Identity::Services::JwtEncoder.decode(token)
        @current_user = Identity::Entities::User.find(payload["sub"])
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        render_error(code: "unauthorized", message: "Invalid or expired token", status: :unauthorized)
      end

      def bearer_token
        request.headers["Authorization"]&.split(" ")&.last
      end

      def current_user
        @current_user
      end
    end
  end
end
