require "swagger_helper"

RSpec.describe "Customer Service Orders", type: :request do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:service)  { create(:service, base_price_cents: 3000) }
  let(:part)     { create(:part, unit_price_cents: 1000) }

  before do
    allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret")
    create(:stock_movement, part: part, performed_by_user: admin, movement_type: "inbound", quantity: 5)
  end

  def create_order_awaiting_approval
    result = ServiceOrders::UseCases::CreateOrder.call(
      { customer_id: customer.id, vehicle_id: vehicle.id,
        items: [{ service_id: service.id, quantity: 1 }, { part_id: part.id, quantity: 1 }] },
      performed_by: admin
    )
    order = result.payload
    ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "start_diagnosis", performed_by: admin)
    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "send_for_approval", performed_by: admin)
    token = tr.payload[:approval_link].match(/token=(.+)$/)[1]
    { order: order.reload, token: token }
  end

  path "/api/v1/customer/service_orders/{uuid}" do
    parameter name: :uuid, in: :path, type: :string,
              description: "UUID público da ordem de serviço (recebido no link enviado ao cliente)",
              example: "550e8400-e29b-41d4-a716-446655440000"

    get "Shows order status to customer" do
      tags "Customer"
      produces "application/json"
      description "Endpoint público (sem autenticação). Retorna status, itens e histórico da OS. Use o UUID do link enviado ao cliente."

      response "200", "order found" do
        let(:order)  { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:uuid)   { order.uuid }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["uuid"]).to be_present
          expect(data["status"]).to eq("received")
          expect(data["vehicle"]).to be_present
          expect(data["items"]).to be_an(Array)
          expect(data["history"]).to be_an(Array)
        end
      end

      response "404", "order not found" do
        let(:uuid) { "nonexistent-uuid" }
        run_test!
      end
    end
  end

  path "/api/v1/customer/service_orders/{uuid}/approve" do
    parameter name: :uuid, in: :path, type: :string,
              description: "UUID público da ordem de serviço",
              example: "550e8400-e29b-41d4-a716-446655440000"

    post "Customer approves the service order" do
      tags "Customer"
      consumes "application/json"
      produces "application/json"
      description "Endpoint público (sem autenticação). O token é recebido pelo cliente via link (SMS/e-mail). Aprovação move a OS para 'approved'; o atendente inicia a execução via start_execution."
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          token: {
            type: :string,
            description: "Token de aprovação recebido no link enviado ao cliente. Válido por 7 dias.",
            example: "xK9mP2qL8nR5vT1wY3zA6bC4dE7fG0hJ"
          }
        },
        required: %w[token],
        example: { token: "xK9mP2qL8nR5vT1wY3zA6bC4dE7fG0hJ" }
      }

      response "200", "order approved" do
        let(:data)  { create_order_awaiting_approval }
        let(:uuid)  { data[:order].uuid }
        let(:body)  { { token: data[:token] } }
        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["status"]).to eq("approved")
        end
      end

      response "422", "invalid token" do
        let(:data)  { create_order_awaiting_approval }
        let(:uuid)  { data[:order].uuid }
        let(:body)  { { token: "wrong_token" } }
        run_test!
      end
    end
  end

  path "/api/v1/customer/service_orders/{uuid}/reject" do
    parameter name: :uuid, in: :path, type: :string,
              description: "UUID público da ordem de serviço",
              example: "550e8400-e29b-41d4-a716-446655440000"

    post "Customer rejects the service order" do
      tags "Customer"
      consumes "application/json"
      produces "application/json"
      description "Endpoint público (sem autenticação). Rejeição zera o total da OS e não movimenta estoque. O veículo ainda será entregue (transição para 'delivered' pelo atendente)."
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          token: {
            type: :string,
            description: "Token de aprovação recebido no link enviado ao cliente. Válido por 7 dias.",
            example: "xK9mP2qL8nR5vT1wY3zA6bC4dE7fG0hJ"
          }
        },
        required: %w[token],
        example: { token: "xK9mP2qL8nR5vT1wY3zA6bC4dE7fG0hJ" }
      }

      response "200", "order rejected" do
        let(:data)  { create_order_awaiting_approval }
        let(:uuid)  { data[:order].uuid }
        let(:body)  { { token: data[:token] } }
        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json["status"]).to eq("finished")
        end
      end

      response "422", "invalid token" do
        let(:data)  { create_order_awaiting_approval }
        let(:uuid)  { data[:order].uuid }
        let(:body)  { { token: "bad_token" } }
        run_test!
      end
    end
  end
end
