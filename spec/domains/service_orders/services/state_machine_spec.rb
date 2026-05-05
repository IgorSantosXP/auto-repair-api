require "rails_helper"

RSpec.describe ServiceOrders::Services::StateMachine do
  describe ".transition" do
    it "allows received -> in_diagnosis" do
      expect(described_class.transition("received", "start_diagnosis")).to eq("in_diagnosis")
    end

    it "allows in_diagnosis -> awaiting_approval" do
      expect(described_class.transition("in_diagnosis", "send_for_approval")).to eq("awaiting_approval")
    end

    it "allows awaiting_approval -> approved on approve" do
      expect(described_class.transition("awaiting_approval", "approve")).to eq("approved")
    end

    it "allows approved -> in_execution on start_execution" do
      expect(described_class.transition("approved", "start_execution")).to eq("in_execution")
    end

    it "allows awaiting_approval -> finished on reject" do
      expect(described_class.transition("awaiting_approval", "reject")).to eq("finished")
    end

    it "allows in_execution -> finished" do
      expect(described_class.transition("in_execution", "finalize")).to eq("finished")
    end

    it "allows finished -> delivered" do
      expect(described_class.transition("finished", "deliver")).to eq("delivered")
    end

    it "returns nil for invalid transition" do
      expect(described_class.transition("received", "finalize")).to be_nil
    end

    it "returns nil for unknown event" do
      expect(described_class.transition("received", "nonexistent")).to be_nil
    end

    it "returns nil from terminal status" do
      expect(described_class.transition("delivered", "deliver")).to be_nil
    end
  end

  describe ".valid_events_for" do
    it "returns correct events for received" do
      expect(described_class.valid_events_for("received")).to eq(["start_diagnosis"])
    end

    it "returns empty for delivered" do
      expect(described_class.valid_events_for("delivered")).to be_empty
    end
  end
end
