module Registries
  module ValueObjects
    class Cnpj
      BLACKLIST = %w[
        00000000000000 11111111111111 22222222222222 33333333333333
        44444444444444 55555555555555 66666666666666 77777777777777
        88888888888888 99999999999999
      ].freeze

      WEIGHTS_FIRST  = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze
      WEIGHTS_SECOND = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze

      attr_reader :value

      def initialize(value)
        @value = value.to_s.gsub(/\D/, "")
      end

      def valid?
        return false if value.length != 14
        return false if BLACKLIST.include?(value)

        valid_first_digit? && valid_second_digit?
      end

      def normalized
        value
      end

      private

      def calc_digit(digits, weights)
        sum = digits.each_with_index.sum { |d, i| d.to_i * weights[i] }
        remainder = sum % 11
        remainder < 2 ? 0 : 11 - remainder
      end

      def valid_first_digit?
        calc_digit(value[0..11].chars, WEIGHTS_FIRST) == value[12].to_i
      end

      def valid_second_digit?
        calc_digit(value[0..12].chars, WEIGHTS_SECOND) == value[13].to_i
      end
    end
  end
end
