module Api
  module V1
    class AuthController < ApplicationController
      def login
        result = Identity::UseCases::AuthenticateUser.call(
          email: params[:email],
          password: params[:password]
        )

        if result.success?
          render_success({
            token: result.payload[:token],
            user: result.payload[:user]
          })
        else
          render_error(
            code: "authentication_failed",
            message: result.errors.first,
            status: :unauthorized
          )
        end
      end
    end
  end
end
