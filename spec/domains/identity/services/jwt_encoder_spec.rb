require "rails_helper"

RSpec.describe Identity::Services::JwtEncoder do
  before { allow(described_class).to receive(:secret).and_return("test_secret_key_for_specs") }

  describe ".encode" do
    it "returns a JWT string" do
      token = described_class.encode({ "sub" => 1 })
      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end

    it "includes expiration in the payload" do
      token   = described_class.encode({ "sub" => 1 })
      payload = described_class.decode(token)
      expect(payload["exp"]).to be > Time.current.to_i
    end
  end

  describe ".decode" do
    it "decodes a valid token" do
      token   = described_class.encode({ "sub" => 42 })
      payload = described_class.decode(token)
      expect(payload["sub"]).to eq(42)
    end

    it "raises JWT::DecodeError for an invalid token" do
      expect { described_class.decode("invalid.token.here") }.to raise_error(JWT::DecodeError)
    end

    it "raises JWT::DecodeError for an expired token" do
      expired_payload = { "sub" => 1, "exp" => 1.second.ago.to_i }
      token = JWT.encode(expired_payload, "test_secret_key_for_specs", "HS256")
      expect { described_class.decode(token) }.to raise_error(JWT::DecodeError)
    end
  end
end
