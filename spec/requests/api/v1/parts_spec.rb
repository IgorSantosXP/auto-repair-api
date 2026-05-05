require "swagger_helper"

RSpec.describe "Parts", type: :request do
  let(:admin) { create(:user) }
  let(:token) { Identity::Services::JwtEncoder.encode({ "sub" => admin.id }) }

  before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

  path "/api/v1/parts" do
    get "Lists parts" do
      tags "Parts"
      security [bearerAuth: []]
      produces "application/json"

      response "200", "list returned" do
        let(:Authorization) { "Bearer #{token}" }
        before { create_list(:part, 2) }
        run_test!
      end
    end

    post "Creates a part" do
      tags "Parts"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          sku: {
            type: :string,
            description: "Código único da peça (Stock Keeping Unit)",
            example: "FIL-OLEO-5W30"
          },
          name: {
            type: :string,
            description: "Nome da peça",
            example: "Filtro de óleo 5W30"
          },
          description: {
            type: :string,
            description: "Descrição adicional da peça",
            example: "Filtro de óleo para motores 1.0 a 2.0"
          },
          unit_price_cents: {
            type: :integer,
            description: "Preço unitário em centavos (ex: 2500 = R$ 25,00)",
            example: 2500
          }
        },
        required: %w[sku name unit_price_cents],
        example: {
          sku: "FIL-OLEO-5W30",
          name: "Filtro de óleo 5W30",
          description: "Filtro de óleo para motores 1.0 a 2.0",
          unit_price_cents: 2500
        }
      }

      response "201", "part created" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { sku: "OIL001", name: "Motor Oil 5W30", unit_price_cents: 2500 } }
        run_test!
      end
    end
  end

  path "/api/v1/parts/{id}/stock" do
    parameter name: :id, in: :path, type: :integer, description: "ID da peça", example: 1

    get "Returns current stock balance" do
      tags "Parts"
      security [bearerAuth: []]
      produces "application/json"

      response "200", "balance returned" do
        let(:Authorization) { "Bearer #{token}" }
        let(:part)          { create(:part) }
        let(:id)            { part.id }
        before do
          create(:stock_movement, part: part, performed_by_user: admin,
                 movement_type: "inbound", quantity: 10)
        end
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["balance"]).to eq(10)
        end
      end
    end
  end

  path "/api/v1/parts/{part_id}/stock_movements" do
    parameter name: :part_id, in: :path, type: :integer, description: "ID da peça", example: 1

    post "Registers a stock movement" do
      tags "Parts"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          movement_type: {
            type: :string,
            enum: %w[inbound outbound adjustment_in adjustment_out],
            description: "'inbound' = entrada por compra | 'outbound' = saída por uso | 'adjustment_in' = ajuste positivo | 'adjustment_out' = ajuste negativo",
            example: "inbound"
          },
          quantity: {
            type: :integer,
            description: "Quantidade (sempre positivo — o tipo determina se soma ou subtrai do saldo)",
            example: 10
          },
          reason: {
            type: :string,
            description: "Motivo da movimentação",
            example: "Compra NF 1234"
          }
        },
        required: %w[movement_type quantity],
        example: {
          movement_type: "inbound",
          quantity: 10,
          reason: "Compra NF 1234"
        }
      }

      response "201", "movement registered" do
        let(:Authorization) { "Bearer #{token}" }
        let(:part)          { create(:part) }
        let(:part_id)       { part.id }
        let(:body)          { { movement_type: "inbound", quantity: 20, reason: "purchase" } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["quantity"]).to eq(20)
        end
      end

      response "422", "insufficient stock" do
        let(:Authorization) { "Bearer #{token}" }
        let(:part)          { create(:part) }
        let(:part_id)       { part.id }
        let(:body)          { { movement_type: "outbound", quantity: 999, reason: "test" } }
        run_test!
      end
    end
  end
end
