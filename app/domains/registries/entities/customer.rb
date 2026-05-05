module Registries
  module Entities
    class Customer < ApplicationRecord
      self.table_name = "customers"

      KINDS = %w[individual company].freeze

      has_many :vehicles, class_name: "Registries::Entities::Vehicle",
               foreign_key: :customer_id, dependent: :destroy

      validates :kind,     presence: true, inclusion: { in: KINDS }
      validates :document, presence: true
      validates :name,     presence: true

      validate :document_format

      default_scope { where(deleted_at: nil) }

      def as_json(*)
        super(except: %i[deleted_at])
      end

      private

      def document_format
        return if document.blank?

        vo = kind == "individual" ? ValueObjects::Cpf.new(document) : ValueObjects::Cnpj.new(document)
        unless vo.valid?
          errors.add(:document, "is invalid")
        end
      end
    end
  end
end
