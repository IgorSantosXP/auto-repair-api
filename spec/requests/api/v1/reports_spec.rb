require "swagger_helper"

RSpec.describe "Reports", type: :request do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:token)    { Identity::Services::JwtEncoder.encode({ "sub" => admin.id }) }

  before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

  path "/api/v1/reports/metrics" do
    get "Returns average execution time metrics" do
      tags "Reports"
      security [bearerAuth: []]
      produces "application/json"
      description "Retorna o tempo médio de execução das ordens de serviço finalizadas. Calculado com base em execution_started_at e finished_at."
      parameter name: :from, in: :query, type: :string, required: false,
                description: "Data inicial do período (YYYY-MM-DD). Filtra por execution_started_at.",
                example: "2026-01-01"
      parameter name: :to, in: :query, type: :string, required: false,
                description: "Data final do período (YYYY-MM-DD). Filtra por finished_at.",
                example: "2026-12-31"

      response "200", "metrics returned" do
        let(:Authorization) { "Bearer #{token}" }
        before do
          create(:service_order, customer: customer, vehicle: vehicle,
                 status: "finished",
                 execution_started_at: 5.hours.ago,
                 finished_at: 1.hour.ago)
        end
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["total_orders"]).to eq(1)
          expect(data["average_seconds"]).to be_present
          expect(data["average_hours"]).to be_present
          expect(data["period"]).to be_present
        end
      end

      response "200", "empty result when no orders" do
        let(:Authorization) { "Bearer #{token}" }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["total_orders"]).to eq(0)
          expect(data["average_seconds"]).to be_nil
        end
      end

      response "400", "invalid date format" do
        let(:Authorization) { "Bearer #{token}" }
        let(:from)          { "not-a-date" }
        run_test!
      end

      response "401", "unauthorized" do
        let(:Authorization) { "Bearer invalid" }
        run_test!
      end
    end
  end
end
