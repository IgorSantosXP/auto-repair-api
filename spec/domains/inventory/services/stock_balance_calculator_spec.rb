require "rails_helper"

RSpec.describe Inventory::Services::StockBalanceCalculator do
  let(:part) { create(:part) }
  let(:user) { create(:user) }

  def movement(type, qty)
    create(:stock_movement, part: part, performed_by_user: user, movement_type: type, quantity: qty)
  end

  describe ".balance_for" do
    it "starts at zero with no movements" do
      expect(described_class.balance_for(part.id)).to eq(0)
    end

    it "adds inbound movements" do
      movement("inbound", 10)
      movement("inbound", 5)
      expect(described_class.balance_for(part.id)).to eq(15)
    end

    it "subtracts outbound movements" do
      movement("inbound",  20)
      movement("outbound", 7)
      expect(described_class.balance_for(part.id)).to eq(13)
    end

    it "handles adjustment_in and adjustment_out" do
      movement("inbound",        10)
      movement("adjustment_in",   5)
      movement("adjustment_out",  3)
      expect(described_class.balance_for(part.id)).to eq(12)
    end

    it "is isolated per part" do
      other_part = create(:part)
      movement("inbound", 10)
      create(:stock_movement, part: other_part, performed_by_user: user, movement_type: "inbound", quantity: 99)

      expect(described_class.balance_for(part.id)).to eq(10)
    end
  end
end
