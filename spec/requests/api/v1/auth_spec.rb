require "swagger_helper"

RSpec.describe "Auth", type: :request do
  path "/api/v1/auth/login" do
    post "Authenticates an admin user" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"

      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email:    { type: :string, example: "admin@autorepair.com" },
          password: { type: :string, example: "admin123456" }
        },
        required: %w[email password]
      }

      response "200", "successful login" do
        schema type: :object, properties: {
          token: { type: :string },
          user:  {
            type: :object,
            properties: {
              id:    { type: :integer },
              email: { type: :string },
              name:  { type: :string },
              role:  { type: :string }
            }
          }
        }

        let(:user)        { create(:user, email: "admin@test.com", password: "password123") }
        let(:credentials) { { email: user.email, password: "password123" } }

        before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["token"]).to be_present
          expect(data["user"]["email"]).to eq(user.email)
        end
      end

      response "401", "invalid credentials" do
        schema type: :object, properties: {
          error: {
            type: :object,
            properties: {
              code:    { type: :string },
              message: { type: :string }
            }
          }
        }

        let(:credentials) { { email: "wrong@test.com", password: "wrong" } }
        run_test!
      end
    end
  end
end
