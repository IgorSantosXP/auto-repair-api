module ServiceOrders
  module Services
    class BudgetCalculator
      def self.calculate(items)
        items.sum { |item| item.quantity * item.unit_price_cents }
      end
    end
  end
end
