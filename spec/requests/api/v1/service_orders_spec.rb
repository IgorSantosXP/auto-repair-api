require "swagger_helper"

RSpec.describe "Service Orders", type: :request do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:service)  { create(:service, base_price_cents: 5000) }
  let(:part)     { create(:part, unit_price_cents: 2000) }
  let(:token)    { Identity::Services::JwtEncoder.encode({ "sub" => admin.id }) }

  before do
    allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret")
    create(:stock_movement, part: part, performed_by_user: admin, movement_type: "inbound", quantity: 10)
  end

  path "/api/v1/service_orders" do
    get "Lists service orders" do
      tags "Service Orders"
      security [bearerAuth: []]
      produces "application/json"
      parameter name: :page,        in: :query, type: :integer, required: false, example: 1
      parameter name: :per_page,    in: :query, type: :integer, required: false, example: 20
      parameter name: :status,      in: :query, type: :string,  required: false,
                description: "Filtrar por status: received | in_diagnosis | awaiting_approval | in_execution | finished | delivered",
                example: "received"
      parameter name: :customer_id, in: :query, type: :integer, required: false, description: "Filtrar por ID do cliente"
      parameter name: :vehicle_id,  in: :query, type: :integer, required: false, description: "Filtrar por ID do veículo"
      parameter name: :from,        in: :query, type: :string,  required: false, description: "Data inicial (YYYY-MM-DD)", example: "2026-01-01"
      parameter name: :to,          in: :query, type: :string,  required: false, description: "Data final (YYYY-MM-DD)",   example: "2026-12-31"

      response "200", "list returned" do
        let(:Authorization) { "Bearer #{token}" }
        before { create(:service_order, customer: customer, vehicle: vehicle) }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(1)
        end
      end

      response "401", "unauthorized" do
        let(:Authorization) { "Bearer invalid" }
        run_test!
      end
    end

    post "Creates a service order" do
      tags "Service Orders"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          customer_id: {
            type: :integer,
            description: "ID do cliente",
            example: 1
          },
          vehicle_id: {
            type: :integer,
            description: "ID do veículo",
            example: 1
          },
          diagnosis_notes: {
            type: :string,
            description: "Observações do diagnóstico inicial (opcional)",
            example: "Cliente relata barulho ao frear"
          },
          items: {
            type: :array,
            description: "Lista de serviços e/ou peças da OS. Cada item deve ter exatamente um de service_id ou part_id.",
            items: {
              type: :object,
              properties: {
                service_id: {
                  type: :integer,
                  description: "ID do serviço (use este ou part_id, nunca ambos)",
                  example: 1
                },
                part_id: {
                  type: :integer,
                  description: "ID da peça (use este ou service_id, nunca ambos)",
                  example: 2
                },
                quantity: {
                  type: :integer,
                  description: "Quantidade",
                  example: 1
                }
              }
            }
          }
        },
        required: %w[customer_id vehicle_id items],
        example: {
          customer_id: 1,
          vehicle_id: 1,
          diagnosis_notes: "Cliente relata barulho ao frear",
          items: [
            { service_id: 1, quantity: 1 },
            { part_id: 2, quantity: 2 }
          ]
        }
      }

      response "201", "order created" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) do
          {
            customer_id: customer.id,
            vehicle_id:  vehicle.id,
            items: [{ service_id: service.id, quantity: 1 }]
          }
        end
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["status"]).to eq("received")
          expect(data["total_cents"]).to eq(5000)
        end
      end

      response "422", "validation error" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { customer_id: 0, vehicle_id: vehicle.id, items: [] } }
        run_test!
      end
    end
  end

  path "/api/v1/service_orders/{id}" do
    parameter name: :id, in: :path, type: :integer, description: "ID da ordem de serviço", example: 1

    get "Shows a service order" do
      tags "Service Orders"
      security [bearerAuth: []]
      produces "application/json"

      response "200", "order found" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order)         { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:id)            { order.id }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["status"]).to eq("received")
          expect(data["available_events"]).to eq(["start_diagnosis"])
        end
      end

      response "404", "order not found" do
        let(:Authorization) { "Bearer #{token}" }
        let(:id)            { 0 }
        run_test!
      end
    end

    patch "Updates a service order" do
      tags "Service Orders"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        description: "Apenas ordens em status 'received' ou 'in_diagnosis' podem ser atualizadas.",
        properties: {
          diagnosis_notes: {
            type: :string,
            description: "Observações do diagnóstico",
            example: "Pastilhas de freio dianteiras desgastadas. Disco com leve empenamento."
          },
          items: {
            type: :array,
            description: "Substitui todos os itens da OS",
            items: {
              type: :object,
              properties: {
                service_id: { type: :integer, example: 1 },
                part_id:    { type: :integer, example: 2 },
                quantity:   { type: :integer, example: 1 }
              }
            }
          }
        },
        example: {
          diagnosis_notes: "Pastilhas de freio dianteiras desgastadas.",
          items: [{ service_id: 1, quantity: 1 }, { part_id: 2, quantity: 2 }]
        }
      }

      response "200", "order updated" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order)         { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:id)            { order.id }
        let(:body)          { { diagnosis_notes: "Needs oil change" } }
        run_test!
      end

      response "422", "cannot update in current status" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order) { create(:service_order, customer: customer, vehicle: vehicle, status: "delivered") }
        let(:id)    { order.id }
        let(:body)  { { diagnosis_notes: "Late update" } }
        run_test!
      end
    end
  end

  path "/api/v1/service_orders/{id}/transitions" do
    parameter name: :id, in: :path, type: :integer, description: "ID da ordem de serviço", example: 1

    post "Transitions a service order to a new status" do
      tags "Service Orders"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          event: {
            type: :string,
            enum: %w[start_diagnosis send_for_approval start_execution finalize deliver],
            description: [
              "Eventos disponíveis por status:",
              "  received → start_diagnosis",
              "  in_diagnosis → send_for_approval (gera link de aprovação para o cliente)",
              "  awaiting_approval → send_for_approval (reenvia link, invalida token anterior)",
              "  approved → start_execution (reserva estoque e inicia execução)",
              "  in_execution → finalize",
              "  finished → deliver"
            ].join("\n"),
            example: "start_diagnosis"
          },
        },
        required: %w[event],
        example: { event: "start_diagnosis" }
      }

      response "200", "transition successful" do
        schema type: :object,
               properties: {
                 order: {
                   type: :object,
                   properties: {
                     id:               { type: :integer },
                     uuid:             { type: :string },
                     status:           { type: :string, example: "in_diagnosis" },
                     total_cents:      { type: :integer },
                     available_events: {
                       type: :array,
                       items: { type: :string },
                       description: "Events that can be triggered from the current status",
                       example: ["send_for_approval"]
                     }
                   }
                 },
                 approval_link: {
                   type: :string,
                   nullable: true,
                   description: "Only present when event is 'send_for_approval'",
                   example: "/api/v1/customer/service_orders/uuid/approve?token=abc123"
                 }
               }

        let(:Authorization) { "Bearer #{token}" }
        let(:order) do
          ServiceOrders::UseCases::CreateOrder.call(
            { customer_id: customer.id, vehicle_id: vehicle.id,
              items: [{ service_id: service.id, quantity: 1 }] },
            performed_by: admin
          ).payload
        end
        let(:id)   { order.id }
        let(:body) { { event: "start_diagnosis" } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["order"]["status"]).to eq("in_diagnosis")
          expect(data["order"]["available_events"]).to eq(["send_for_approval"])
        end
      end

      response "422", "invalid transition" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order)         { create(:service_order, customer: customer, vehicle: vehicle, status: "received") }
        let(:id)            { order.id }
        let(:body)          { { event: "finalize" } }
        run_test!
      end
    end
  end
end
