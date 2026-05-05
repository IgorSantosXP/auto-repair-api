require "rails_helper"

RSpec.describe ServiceOrders::Services::BudgetCalculator do
  describe ".calculate" do
    it "returns 0 for empty items" do
      expect(described_class.calculate([])).to eq(0)
    end

    it "sums quantity * unit_price_cents" do
      items = [
        double(quantity: 2, unit_price_cents: 1000),
        double(quantity: 1, unit_price_cents: 500)
      ]
      expect(described_class.calculate(items)).to eq(2500)
    end
  end
end
