require "jwt"

module Identity
  module Services
    class JwtEncoder
      ALGORITHM = "HS256"

      ADMIN_AUDIENCE    = "admin".freeze
      CUSTOMER_AUDIENCE = "customer".freeze

      ADMIN_ISSUER    = "auto-repair-api".freeze
      CUSTOMER_ISSUER = "auto-repair-auth".freeze

      EXPIRY = 24.hours

      ISSUERS = {
        ADMIN_AUDIENCE    => ADMIN_ISSUER,
        CUSTOMER_AUDIENCE => CUSTOMER_ISSUER
      }.freeze

      def self.encode(payload, audience: ADMIN_AUDIENCE)
        JWT.encode(
          payload.merge(
            "aud" => audience,
            "iss" => ISSUERS.fetch(audience),
            "exp" => EXPIRY.from_now.to_i
          ),
          secret,
          ALGORITHM
        )
      end

      def self.decode(token, audience: ADMIN_AUDIENCE)
        JWT.decode(token, secret, true, {
          algorithm:  ALGORITHM,
          verify_aud: true,
          aud:        audience,
          verify_iss: true,
          iss:        ISSUERS.fetch(audience)
        }).first
      end

      def self.secret
        Rails.application.credentials.jwt_secret ||
          ENV.fetch("JWT_SECRET") { raise "JWT_SECRET is not configured" }
      end
    end
  end
end
