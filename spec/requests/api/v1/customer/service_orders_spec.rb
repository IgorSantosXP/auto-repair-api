require "swagger_helper"

RSpec.describe "Customer Service Orders", type: :request do
  let(:admin)          { create(:user) }
  let(:customer)       { create(:customer) }
  let(:vehicle)        { create(:vehicle, customer: customer) }
  let(:other_customer) { create(:customer) }
  let(:other_vehicle)  { create(:vehicle, customer: other_customer) }

  let(:customer_token) do
    Identity::Services::JwtEncoder.encode(
      { "sub" => customer.id.to_s },
      audience: Identity::Services::JwtEncoder::CUSTOMER_AUDIENCE
    )
  end
  before do
    allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret")
  end

  path "/api/v1/customer/service_orders" do
    get "Lists the authenticated customer own orders" do
      tags "Customer"
      produces "application/json"
      security [ bearerAuth: [] ]
      description "Requer o token emitido por POST /auth/cpf (Lambda de autenticação). Retorna apenas as OS do cliente autenticado."

      response "200", "orders listed" do
        let(:Authorization) { "Bearer #{customer_token}" }

        before do
          create(:service_order, customer: customer, vehicle: vehicle)
          create(:service_order, customer: other_customer, vehicle: other_vehicle)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.size).to eq(1)
          expect(data.first["uuid"]).to be_present
        end
      end

      response "401", "missing or invalid token" do
        let(:Authorization) { "Bearer nonsense" }
        run_test!
      end
    end
  end

  path "/api/v1/customer/service_orders/{uuid}" do
    parameter name: :uuid, in: :path, type: :string,
              description: "UUID público da ordem de serviço (recebido no link enviado ao cliente)",
              example: "550e8400-e29b-41d4-a716-446655440000"

    get "Shows order status to customer" do
      tags "Customer"
      produces "application/json"
      security [ bearerAuth: [] ]
      description "Requer o token emitido por POST /auth/cpf (Lambda de autenticação). Retorna status, itens e histórico da OS."

      response "200", "order found" do
        let(:order)         { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:uuid)          { order.uuid }
        let(:Authorization) { "Bearer #{customer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["uuid"]).to be_present
          expect(data["status"]).to eq("received")
          expect(data["vehicle"]).to be_present
          expect(data["items"]).to be_an(Array)
          expect(data["history"]).to be_an(Array)
          expect(data).to have_key("payment_url")
        end
      end

      response "401", "missing or invalid token" do
        let(:order)         { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:uuid)          { order.uuid }
        let(:Authorization) { "Bearer nonsense" }
        run_test!
      end

      response "401", "admin token is not accepted on customer routes" do
        let(:order)         { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:uuid)          { order.uuid }
        let(:Authorization) { "Bearer #{Identity::Services::JwtEncoder.encode({ 'sub' => admin.id })}" }
        run_test!
      end

      response "403", "order belongs to another customer" do
        let(:order)         { create(:service_order, customer: other_customer, vehicle: other_vehicle) }
        let(:uuid)          { order.uuid }
        let(:Authorization) { "Bearer #{customer_token}" }
        run_test!
      end

      response "404", "order not found" do
        let(:uuid)          { "nonexistent-uuid" }
        let(:Authorization) { "Bearer #{customer_token}" }
        run_test!
      end
    end
  end
end
