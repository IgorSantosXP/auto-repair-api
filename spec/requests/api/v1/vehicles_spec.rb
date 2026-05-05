require "swagger_helper"

RSpec.describe "Vehicles", type: :request do
  let(:admin)    { create(:user) }
  let(:token)    { Identity::Services::JwtEncoder.encode({ "sub" => admin.id }) }
  let(:customer) { create(:customer) }

  before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

  path "/api/v1/vehicles" do
    get "Lists vehicles" do
      tags "Vehicles"
      security [bearerAuth: []]
      produces "application/json"
      parameter name: :customer_id,   in: :query, type: :integer, required: false, description: "Filtrar por ID do cliente"
      parameter name: :license_plate, in: :query, type: :string,  required: false, description: "Filtrar por placa (parcial)", example: "ABC1234"

      response "200", "list returned" do
        let(:Authorization) { "Bearer #{token}" }
        before { create_list(:vehicle, 2, customer: customer) }
        run_test!
      end
    end

    post "Creates a vehicle" do
      tags "Vehicles"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          customer_id: {
            type: :integer,
            description: "ID do cliente proprietário",
            example: 1
          },
          license_plate: {
            type: :string,
            description: "Placa no formato Mercosul (ABC1D23) ou antigo (ABC1234). Maiúsculas ou minúsculas aceitas.",
            example: "ABC1D23"
          },
          brand: { type: :string, description: "Marca do veículo",  example: "Toyota" },
          model: { type: :string, description: "Modelo do veículo", example: "Corolla" },
          year:  { type: :integer, description: "Ano de fabricação", example: 2022 }
        },
        required: %w[customer_id license_plate brand model year],
        example: {
          customer_id: 1,
          license_plate: "ABC1D23",
          brand: "Toyota",
          model: "Corolla",
          year: 2022
        }
      }

      response "201", "vehicle created" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { customer_id: customer.id, license_plate: "ABC1234", brand: "Toyota", model: "Corolla", year: 2022 } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["license_plate"]).to eq("ABC1234")
        end
      end

      response "422", "invalid plate" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { customer_id: customer.id, license_plate: "INVALID", brand: "X", model: "Y", year: 2020 } }
        run_test!
      end
    end
  end

  path "/api/v1/customers/{customer_id}/vehicles" do
    parameter name: :customer_id, in: :path, type: :integer, description: "ID do cliente", example: 1

    get "Lists vehicles for a customer" do
      tags "Vehicles"
      security [bearerAuth: []]
      produces "application/json"

      response "200", "list returned" do
        let(:Authorization) { "Bearer #{token}" }
        let(:customer_id)   { customer.id }
        before { create_list(:vehicle, 2, customer: customer) }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(2)
        end
      end
    end
  end
end
