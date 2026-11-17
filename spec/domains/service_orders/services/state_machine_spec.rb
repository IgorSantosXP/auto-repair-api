require "rails_helper"

RSpec.describe ServiceOrders::Services::StateMachine do
  describe ".transition" do
    {
      ["received", "budget_generated"]          => "awaiting_approval",
      ["awaiting_approval", "budget_approved"]  => "awaiting_payment",
      ["awaiting_payment", "payment_confirmed"] => "approved",
      ["approved", "start_diagnosis"]           => "in_diagnosis",
      ["in_diagnosis", "start_repair"]          => "in_execution",
      ["in_execution", "finish"]                => "finished",
      ["finished", "deliver"]                   => "delivered",
      ["awaiting_approval", "cancel"]           => "cancelled",
      ["approved", "cancel"]                    => "cancelled"
    }.each do |(from, event), to|
      it "moves #{from} --#{event}--> #{to}" do
        expect(described_class.transition(from, event)).to eq(to)
      end
    end

    it "returns nil for an invalid event" do
      expect(described_class.transition("received", "deliver")).to be_nil
    end

    it "does not allow cancelling once the repair started" do
      expect(described_class.transition("in_execution", "cancel")).to be_nil
    end
  end

  describe ".valid_events_for" do
    it "lists the events of a status" do
      expect(described_class.valid_events_for("received")).to eq(%w[budget_generated cancel])
    end

    it "returns empty for terminal statuses" do
      expect(described_class.valid_events_for("delivered")).to eq([])
      expect(described_class.valid_events_for("cancelled")).to eq([])
    end
  end

  describe ".admin_events_for" do
    it "only exposes events an admin can trigger" do
      expect(described_class.admin_events_for("finished")).to eq(["deliver"])
      expect(described_class.admin_events_for("received")).to eq([])
    end
  end

  describe ".valid_transition?" do
    it { expect(described_class.valid_transition?("finished", "deliver")).to be true }
    it { expect(described_class.valid_transition?("received", "finish")).to be false }
  end
end
