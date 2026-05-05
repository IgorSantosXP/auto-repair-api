require "rails_helper"

RSpec.describe Registries::ValueObjects::Cpf do
  describe "#valid?" do
    it "accepts a valid CPF" do
      expect(described_class.new("529.982.247-25")).to be_valid
    end

    it "accepts digits-only CPF" do
      expect(described_class.new("52998224725")).to be_valid
    end

    it "rejects all-same-digit CPF" do
      expect(described_class.new("111.111.111-11")).not_to be_valid
    end

    it "rejects wrong length" do
      expect(described_class.new("123")).not_to be_valid
    end

    it "rejects bad check digits" do
      expect(described_class.new("529.982.247-26")).not_to be_valid
    end
  end

  describe "#normalized" do
    it "strips formatting characters" do
      expect(described_class.new("529.982.247-25").normalized).to eq("52998224725")
    end
  end
end
