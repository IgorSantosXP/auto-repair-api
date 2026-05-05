require "jwt"

module Identity
  module Services
    class JwtEncoder
      ALGORITHM = "HS256"
      EXPIRY    = 24.hours

      def self.encode(payload)
        JWT.encode(payload.merge(exp: EXPIRY.from_now.to_i), secret, ALGORITHM)
      end

      def self.decode(token)
        JWT.decode(token, secret, true, { algorithm: ALGORITHM }).first
      end

      def self.secret
        Rails.application.credentials.jwt_secret ||
          ENV.fetch("JWT_SECRET") { raise "JWT_SECRET is not configured" }
      end
    end
  end
end
