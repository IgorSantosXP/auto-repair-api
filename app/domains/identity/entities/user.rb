module Identity
  module Entities
    class User < ApplicationRecord
      self.table_name = "users"

      has_secure_password

      validates :email, presence: true, uniqueness: { case_sensitive: false },
                        format: { with: URI::MailTo::EMAIL_REGEXP }
      validates :name, presence: true
      validates :role, presence: true, inclusion: { in: %w[admin] }
      validates :password, length: { minimum: 8 }, allow_nil: true

      before_save { self.email = email.downcase }

      def as_json(*)
        super(only: %i[id email name role created_at updated_at])
      end
    end
  end
end
