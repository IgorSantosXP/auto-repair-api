require "swagger_helper"

RSpec.describe "Service Orders", type: :request do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:service)  { create(:service, base_price_cents: 5000) }
  let(:token)    { Identity::Services::JwtEncoder.encode({ "sub" => admin.id }) }

  before do
    allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret")
  end

  path "/api/v1/service_orders" do
    get "Lists service orders" do
      tags "Service Orders"
      security [bearerAuth: []]
      produces "application/json"
      description [
        "Ordenação padrão: Em Execução > Aguardando Aprovação > Aguardando Pagamento > Aprovada > Diagnóstico > Recebida, mais antigas primeiro.",
        "Ordens finalizadas, entregues e canceladas são excluídas da listagem; use o filtro de status para consultá-las."
      ].join(" ")
      parameter name: :page,        in: :query, type: :integer, required: false, example: 1
      parameter name: :per_page,    in: :query, type: :integer, required: false, example: 20
      parameter name: :status,      in: :query, type: :string,  required: false,
                description: "Filtrar por status: received | awaiting_approval | awaiting_payment | approved | in_diagnosis | in_execution | finished | delivered | cancelled",
                example: "received"
      parameter name: :customer_id, in: :query, type: :integer, required: false, description: "Filtrar por ID do cliente"
      parameter name: :vehicle_id,  in: :query, type: :integer, required: false, description: "Filtrar por ID do veículo"
      parameter name: :from,        in: :query, type: :string,  required: false, description: "Data inicial (YYYY-MM-DD)", example: "2026-01-01"
      parameter name: :to,          in: :query, type: :string,  required: false, description: "Data final (YYYY-MM-DD)",   example: "2026-12-31"

      response "200", "list returned" do
        let(:Authorization) { "Bearer #{token}" }
        before do
          create(:service_order, customer: customer, vehicle: vehicle, status: "received")
          create(:service_order, customer: customer, vehicle: vehicle, status: "in_execution")
          create(:service_order, customer: customer, vehicle: vehicle, status: "delivered")
        end
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(2)
          expect(data.map { |order| order["status"] }).to eq(%w[in_execution received])
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
        description: "Informe customer_id/vehicle_id de registros existentes OU os objetos customer/vehicle com os dados completos (busca por documento/placa; cria se não existir).",
        properties: {
          customer_id: {
            type: :integer,
            description: "ID do cliente já cadastrado (alternativa ao objeto customer)",
            example: 1
          },
          vehicle_id: {
            type: :integer,
            description: "ID do veículo já cadastrado (alternativa ao objeto vehicle)",
            example: 1
          },
          customer: {
            type: :object,
            description: "Dados do cliente — reutiliza cadastro existente pelo documento ou cria um novo",
            properties: {
              kind:     { type: :string, enum: %w[individual company], example: "individual" },
              document: { type: :string, example: "529.982.247-25" },
              name:     { type: :string, example: "Maria Silva" },
              email:    { type: :string, example: "maria@example.com" },
              phone:    { type: :string, example: "11 99999-0000" }
            }
          },
          vehicle: {
            type: :object,
            description: "Dados do veículo — reutiliza cadastro existente pela placa ou cria um novo",
            properties: {
              license_plate: { type: :string, example: "ABC1D23" },
              brand:         { type: :string, example: "Fiat" },
              model:         { type: :string, example: "Uno" },
              year:          { type: :integer, example: 2018 }
            }
          },
          diagnosis_notes: {
            type: :string,
            description: "Observações do diagnóstico inicial (opcional)",
            example: "Cliente relata barulho ao frear"
          },
          items: {
            type: :array,
            description: "Lista de serviços e/ou peças da OS (mínimo 1). Cada item deve ter exatamente um de service_id ou part_id. Peças são validadas no catálogo do Execution Service. Ao criar a OS a saga solicita o orçamento ao Billing Service.",
            items: {
              type: :object,
              properties: {
                service_id: {
                  type: :integer,
                  description: "ID do serviço (use este ou part_id, nunca ambos)",
                  example: 1
                },
                part_id: {
                  type: :string,
                  description: "ID da peça no Execution Service (use este ou service_id, nunca ambos)",
                  example: "oleo-5w30"
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
        required: %w[items],
        example: {
          customer_id: 1,
          vehicle_id: 1,
          diagnosis_notes: "Cliente relata barulho ao frear",
          items: [
            { service_id: 1, quantity: 1 },
            { part_id: "oleo-5w30", quantity: 2 }
          ]
        }
      }

      response "201", "order created" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) do
          {
            customer_id: customer.id,
            vehicle_id:  vehicle.id,
            items: [{ service_id: service.id, quantity: 1 }, { part_id: "oleo-5w30", quantity: 2 }]
          }
        end
        before { stub_part("oleo-5w30", name: "Óleo 5W30", unit_price_cents: 2000) }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["status"]).to eq("received")
          expect(data["total_cents"]).to eq(9000)
          expect(data["saga"]["state"]).to eq("budget_requested")
        end
      end

      response "201", "order created with customer and vehicle data", document: false do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) do
          {
            customer: { kind: "individual", document: "529.982.247-25", name: "Maria Silva",
                        email: "maria@example.com" },
            vehicle:  { license_plate: "XYZ9A88", brand: "Fiat", model: "Uno", year: 2018 },
            items:    [{ service_id: service.id, quantity: 1 }]
          }
        end
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["uuid"]).to be_present
          expect(data["customer_id"]).to be_present
          expect(data["vehicle_id"]).to be_present
        end
      end

      response "422", "validation error" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { customer_id: 0, vehicle_id: vehicle.id, items: [] } }
        run_test!
      end

      response "422", "unknown part", document: false do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { customer_id: customer.id, vehicle_id: vehicle.id, items: [{ part_id: "nope", quantity: 1 }] } }
        before { stub_missing_part("nope") }
        run_test! do |response|
          expect(JSON.parse(response.body).dig("error", "details").join).to include("nope")
        end
      end

      response "503", "parts catalog unavailable", document: false do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { customer_id: customer.id, vehicle_id: vehicle.id, items: [{ part_id: "oleo", quantity: 1 }] } }
        before { stub_request(:get, %r{/api/v1/parts/oleo}).to_return(status: 500) }
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
          expect(data["available_events"]).to eq([])
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
        description: "Atualiza as observações de diagnóstico. Itens não podem ser alterados após a saga solicitar o orçamento.",
        properties: {
          diagnosis_notes: {
            type: :string,
            description: "Observações do diagnóstico",
            example: "Pastilhas de freio dianteiras desgastadas. Disco com leve empenamento."
          }
        },
        example: { diagnosis_notes: "Pastilhas de freio dianteiras desgastadas." }
      }

      response "200", "order updated" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order)         { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:id)            { order.id }
        let(:body)          { { diagnosis_notes: "Needs oil change" } }
        run_test!
      end

      response "422", "items cannot be changed", document: false do
        let(:Authorization) { "Bearer #{token}" }
        let(:order) { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:id)    { order.id }
        let(:body)  { { items: [{ service_id: 1, quantity: 1 }] } }
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

  path "/api/v1/service_orders/{id}/deliver" do
    parameter name: :id, in: :path, type: :integer, description: "ID da ordem de serviço", example: 1

    post "Delivers a finished service order to the customer" do
      tags "Service Orders"
      security [bearerAuth: []]
      produces "application/json"
      description [
        "Única transição manual do atendente. As demais são conduzidas pela saga:",
        "received → awaiting_approval (orçamento gerado) → awaiting_payment (orçamento aprovado) →",
        "approved (pagamento confirmado) → in_diagnosis → in_execution → finished (eventos do Execution Service).",
        "Falhas levam a OS para cancelled após a compensação."
      ].join(" ")

      response "200", "order delivered" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order) { create(:service_order, customer: customer, vehicle: vehicle, status: "finished") }
        let(:id)    { order.id }
        run_test! do |response|
          expect(JSON.parse(response.body)["status"]).to eq("delivered")
        end
      end

      response "422", "order is not finished" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order) { create(:service_order, customer: customer, vehicle: vehicle, status: "received") }
        let(:id)    { order.id }
        run_test!
      end

      response "404", "order not found", document: false do
        let(:Authorization) { "Bearer #{token}" }
        let(:id) { 0 }
        run_test!
      end
    end
  end

  path "/api/v1/service_orders/{id}/saga" do
    parameter name: :id, in: :path, type: :integer, description: "ID da ordem de serviço", example: 1

    get "Shows the saga log of a service order" do
      tags "Service Orders"
      security [bearerAuth: []]
      produces "application/json"
      description "Estado atual da saga orquestrada e todos os comandos enviados/eventos recebidos, em ordem."

      response "200", "saga found" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order) do
          ServiceOrders::UseCases::CreateOrder.call(
            { customer_id: customer.id, vehicle_id: vehicle.id, items: [{ service_id: service.id, quantity: 1 }] },
            performed_by: admin
          ).payload
        end
        let(:id) { order.id }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["state"]).to eq("budget_requested")
          expect(data["steps"].first["message_type"]).to eq("billing.generate_budget")
        end
      end

      response "404", "saga not found" do
        let(:Authorization) { "Bearer #{token}" }
        let(:order) { create(:service_order, customer: customer, vehicle: vehicle) }
        let(:id)    { order.id }
        run_test!
      end
    end
  end
end
