module Registries
  module ValueObjects
    class LicensePlate
      MERCOSUL_PATTERN = /\A[A-Z]{3}\d[A-Z]\d{2}\z/
      OLD_PATTERN      = /\A[A-Z]{3}\d{4}\z/

      attr_reader :value

      def initialize(value)
        @value = value.to_s.upcase.gsub(/[-\s]/, "")
      end

      def valid?
        MERCOSUL_PATTERN.match?(value) || OLD_PATTERN.match?(value)
      end

      def normalized
        value
      end
    end
  end
end
