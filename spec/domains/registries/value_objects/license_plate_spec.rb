require "rails_helper"

RSpec.describe Registries::ValueObjects::LicensePlate do
  describe "#valid?" do
    it "accepts Mercosul format" do
      expect(described_class.new("ABC1D23")).to be_valid
    end

    it "accepts old format" do
      expect(described_class.new("ABC1234")).to be_valid
    end

    it "accepts old format with hyphen" do
      expect(described_class.new("ABC-1234")).to be_valid
    end

    it "accepts lowercase and normalizes" do
      expect(described_class.new("abc1d23")).to be_valid
    end

    it "rejects invalid format" do
      expect(described_class.new("12345678")).not_to be_valid
    end

    it "rejects too short" do
      expect(described_class.new("AB1")).not_to be_valid
    end
  end

  describe "#normalized" do
    it "upcases and strips hyphen" do
      expect(described_class.new("abc-1234").normalized).to eq("ABC1234")
    end

    it "normalizes Mercosul" do
      expect(described_class.new("abc1d23").normalized).to eq("ABC1D23")
    end
  end
end
