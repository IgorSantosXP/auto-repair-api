require "rails_helper"

RSpec.describe Registries::ValueObjects::Cnpj do
  describe "#valid?" do
    it "accepts a valid CNPJ" do
      expect(described_class.new("11.222.333/0001-81")).to be_valid
    end

    it "accepts digits-only CNPJ" do
      expect(described_class.new("11222333000181")).to be_valid
    end

    it "rejects all-same-digit CNPJ" do
      expect(described_class.new("11111111111111")).not_to be_valid
    end

    it "rejects wrong length" do
      expect(described_class.new("123")).not_to be_valid
    end

    it "rejects bad check digits" do
      expect(described_class.new("11.222.333/0001-82")).not_to be_valid
    end
  end

  describe "#normalized" do
    it "strips formatting characters" do
      expect(described_class.new("11.222.333/0001-81").normalized).to eq("11222333000181")
    end
  end
end
