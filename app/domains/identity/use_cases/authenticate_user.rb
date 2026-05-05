module Identity
  module UseCases
    class AuthenticateUser
      def self.call(email:, password:)
        user = Entities::User.find_by(email: email.to_s.downcase)

        unless user&.authenticate(password)
          return Result.failure(errors: ["Invalid email or password"])
        end

        token = Services::JwtEncoder.encode({ "sub" => user.id })
        Result.success(payload: { token: token, user: user })
      end
    end
  end
end
