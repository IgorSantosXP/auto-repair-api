require "rails_helper"

RSpec.describe Inventory::UseCases::RegisterMovement do
  let(:part) { create(:part) }
  let(:user) { create(:user) }

  def call(overrides = {})
    described_class.call(**{
      part_id:       part.id,
      movement_type: "inbound",
      quantity:      10,
      reason:        "purchase",
      performed_by:  user
    }.merge(overrides))
  end

  describe ".call" do
    it "registers an inbound movement" do
      result = call
      expect(result).to be_success
      expect(result.payload.movement_type).to eq("inbound")
      expect(Inventory::Services::StockBalanceCalculator.balance_for(part.id)).to eq(10)
    end

    it "rejects invalid movement type" do
      result = call(movement_type: "invalid")
      expect(result).to be_failure
      expect(result.errors.first).to match(/Invalid movement type/)
    end

    it "rejects quantity <= 0" do
      result = call(quantity: 0)
      expect(result).to be_failure
    end

    context "outbound with sufficient stock" do
      before { call(movement_type: "inbound", quantity: 20) }

      it "succeeds and reduces balance" do
        result = call(movement_type: "outbound", quantity: 15)
        expect(result).to be_success
        expect(Inventory::Services::StockBalanceCalculator.balance_for(part.id)).to eq(5)
      end
    end

    context "outbound with insufficient stock" do
      it "returns failure and does not create movement" do
        result = call(movement_type: "outbound", quantity: 5)
        expect(result).to be_failure
        expect(result.errors.first).to match(/Insufficient stock/)
        expect(Inventory::Entities::StockMovement.count).to eq(0)
      end
    end

    it "returns failure for unknown part" do
      result = call(part_id: 0)
      expect(result).to be_failure
      expect(result.errors).to include("Part not found")
    end
  end
end
