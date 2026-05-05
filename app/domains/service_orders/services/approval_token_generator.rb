require "digest"

module ServiceOrders
  module Services
    class ApprovalTokenGenerator
      TTL = 7.days

      def self.generate
        plain   = SecureRandom.urlsafe_base64(32)
        digest  = Digest::SHA256.hexdigest(plain)
        expires = TTL.from_now
        { plain: plain, digest: digest, expires_at: expires }
      end

      def self.valid?(plain_token, stored_digest, expires_at)
        return false if expires_at.nil? || Time.current > expires_at

        generated = Digest::SHA256.hexdigest(plain_token.to_s)
        ActiveSupport::SecurityUtils.secure_compare(generated, stored_digest.to_s)
      end
    end
  end
end
