module Registries
  module Entities
    class Vehicle < ApplicationRecord
      self.table_name = "vehicles"

      belongs_to :customer, class_name: "Registries::Entities::Customer"

      validates :license_plate, presence: true
      validates :brand,         presence: true
      validates :model,         presence: true
      validates :year,          presence: true,
                                numericality: { only_integer: true, greater_than: 1885,
                                                less_than_or_equal_to: -> (_) { Time.current.year + 1 } }

      validate :license_plate_format

      before_validation :normalize_plate

      default_scope { where(deleted_at: nil) }

      def as_json(*)
        super(except: %i[deleted_at])
      end

      private

      def normalize_plate
        self.license_plate = ValueObjects::LicensePlate.new(license_plate).normalized if license_plate.present?
      end

      def license_plate_format
        return if license_plate.blank?

        unless ValueObjects::LicensePlate.new(license_plate).valid?
          errors.add(:license_plate, "is invalid (expected Mercosul AAA1A11 or old format AAA1111)")
        end
      end
    end
  end
end
