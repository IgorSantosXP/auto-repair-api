module Registries
  module ValueObjects
    class Cpf
      BLACKLIST = %w[
        00000000000 11111111111 22222222222 33333333333 44444444444
        55555555555 66666666666 77777777777 88888888888 99999999999
      ].freeze

      attr_reader :value

      def initialize(value)
        @value = value.to_s.gsub(/\D/, "")
      end

      def valid?
        return false if value.length != 11
        return false if BLACKLIST.include?(value)

        valid_first_digit? && valid_second_digit?
      end

      def normalized
        value
      end

      private

      def valid_first_digit?
        sum = value[0..8].chars.each_with_index.sum { |d, i| d.to_i * (10 - i) }
        remainder = sum % 11
        check = remainder < 2 ? 0 : 11 - remainder
        check == value[9].to_i
      end

      def valid_second_digit?
        sum = value[0..9].chars.each_with_index.sum { |d, i| d.to_i * (11 - i) }
        remainder = sum % 11
        check = remainder < 2 ? 0 : 11 - remainder
        check == value[10].to_i
      end
    end
  end
end
