module Registries
  module Entities
    class Service < ApplicationRecord
      self.table_name = "services"

      validates :name,             presence: true
      validates :base_price_cents, presence: true,
                                   numericality: { only_integer: true, greater_than_or_equal_to: 0 }
      validates :estimated_duration_minutes, numericality: { only_integer: true, greater_than: 0 },
                                             allow_nil: true

      default_scope { where(deleted_at: nil) }

      def as_json(*)
        super(except: %i[deleted_at])
      end
    end
  end
end
