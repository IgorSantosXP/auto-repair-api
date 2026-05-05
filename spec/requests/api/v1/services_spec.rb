require "swagger_helper"

RSpec.describe "Services", type: :request do
  let(:admin) { create(:user) }
  let(:token) { Identity::Services::JwtEncoder.encode({ "sub" => admin.id }) }

  before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

  path "/api/v1/services" do
    get "Lists services" do
      tags "Services"
      security [bearerAuth: []]
      produces "application/json"

      response "200", "list returned" do
        let(:Authorization) { "Bearer #{token}" }
        before { create_list(:service, 2) }
        run_test!
      end
    end

    post "Creates a service" do
      tags "Services"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: {
            type: :string,
            description: "Nome do serviço (único no sistema)",
            example: "Troca de óleo"
          },
          description: {
            type: :string,
            description: "Descrição detalhada do serviço",
            example: "Troca de óleo do motor com filtro"
          },
          base_price_cents: {
            type: :integer,
            description: "Preço base em centavos (ex: 5000 = R$ 50,00)",
            example: 8000
          },
          estimated_duration_minutes: {
            type: :integer,
            description: "Duração estimada em minutos",
            example: 60
          }
        },
        required: %w[name base_price_cents],
        example: {
          name: "Troca de óleo",
          description: "Troca de óleo do motor com filtro",
          base_price_cents: 8000,
          estimated_duration_minutes: 60
        }
      }

      response "201", "service created" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { name: "Oil Change", base_price_cents: 5000, estimated_duration_minutes: 60 } }
        run_test! do |response|
          expect(JSON.parse(response.body)["name"]).to eq("Oil Change")
        end
      end
    end
  end

  path "/api/v1/services/{id}" do
    parameter name: :id, in: :path, type: :integer, description: "ID do serviço", example: 1

    get "Shows a service" do
      tags "Services"
      security [bearerAuth: []]

      response "200", "service found" do
        let(:Authorization) { "Bearer #{token}" }
        let(:service)       { create(:service) }
        let(:id)            { service.id }
        run_test!
      end

      response "404", "not found" do
        let(:Authorization) { "Bearer #{token}" }
        let(:id)            { 0 }
        run_test!
      end
    end

    patch "Updates a service" do
      tags "Services"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name:             { type: :string,  description: "Novo nome do serviço",       example: "Troca de óleo premium" },
          base_price_cents: { type: :integer, description: "Novo preço em centavos",     example: 9500 },
          description:      { type: :string,  description: "Nova descrição do serviço",  example: "Óleo sintético 5W40" },
          estimated_duration_minutes: { type: :integer, description: "Nova duração em minutos", example: 45 }
        },
        example: { name: "Troca de óleo premium", base_price_cents: 9500 }
      }

      response "200", "updated" do
        let(:Authorization) { "Bearer #{token}" }
        let(:service)       { create(:service) }
        let(:id)            { service.id }
        let(:body)          { { name: "Updated Oil Change" } }
        run_test!
      end
    end

    delete "Soft deletes a service" do
      tags "Services"
      security [bearerAuth: []]

      response "204", "deleted" do
        let(:Authorization) { "Bearer #{token}" }
        let(:service)       { create(:service) }
        let(:id)            { service.id }
        run_test!
      end
    end
  end
end
