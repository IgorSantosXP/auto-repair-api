require "rails_helper"

RSpec.describe Identity::UseCases::AuthenticateUser do
  let(:user) { create(:user, email: "admin@test.com", password: "password123") }

  before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

  describe ".call" do
    context "with valid credentials" do
      it "returns success with token and user" do
        result = described_class.call(email: user.email, password: "password123")

        expect(result).to be_success
        expect(result.payload[:token]).to be_present
        expect(result.payload[:user]).to eq(user)
      end
    end

    context "with wrong password" do
      it "returns failure" do
        result = described_class.call(email: user.email, password: "wrong")
        expect(result).to be_failure
        expect(result.errors).to include("Invalid email or password")
      end
    end

    context "with unknown email" do
      it "returns failure" do
        result = described_class.call(email: "unknown@test.com", password: "password123")
        expect(result).to be_failure
      end
    end

    context "with case-insensitive email" do
      it "returns success" do
        result = described_class.call(email: user.email.upcase, password: "password123")
        expect(result).to be_success
      end
    end
  end
end
