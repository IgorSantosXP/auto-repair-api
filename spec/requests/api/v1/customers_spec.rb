require "swagger_helper"

RSpec.describe "Customers", type: :request do
  let(:admin)   { create(:user) }
  let(:token)   { Identity::Services::JwtEncoder.encode({ "sub" => admin.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" } }

  before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

  path "/api/v1/customers" do
    get "Lists customers" do
      tags "Customers"
      security [bearerAuth: []]
      produces "application/json"
      parameter name: :page,     in: :query, type: :integer, required: false, example: 1
      parameter name: :per_page, in: :query, type: :integer, required: false, example: 20
      parameter name: :name,     in: :query, type: :string,  required: false, example: "João"

      response "200", "list returned" do
        let(:Authorization) { "Bearer #{token}" }
        before { create_list(:customer, 3) }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data.length).to eq(3)
        end
      end

      response "401", "unauthorized" do
        let(:Authorization) { "Bearer invalid" }
        run_test!
      end
    end

    post "Creates a customer" do
      tags "Customers"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          kind: {
            type: :string,
            enum: %w[individual company],
            description: "'individual' para pessoa física (CPF), 'company' para pessoa jurídica (CNPJ)",
            example: "individual"
          },
          document: {
            type: :string,
            description: "CPF (ex: 529.982.247-25) para individual ou CNPJ (ex: 11.222.333/0001-81) para company. Aceita com ou sem formatação.",
            example: "529.982.247-25"
          },
          name:  { type: :string,  description: "Nome completo ou razão social", example: "João da Silva" },
          email: { type: :string,  description: "E-mail de contato",             example: "joao@email.com" },
          phone: { type: :string,  description: "Telefone com DDD",              example: "11999990000" }
        },
        required: %w[kind document name],
        example: {
          kind: "individual",
          document: "529.982.247-25",
          name: "João da Silva",
          email: "joao@email.com",
          phone: "11999990000"
        }
      }

      response "201", "customer created" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { kind: "individual", document: "529.982.247-25", name: "John Doe", email: "john@test.com" } }
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["name"]).to eq("John Doe")
          expect(data["document"]).to eq("52998224725")
        end
      end

      response "422", "validation error" do
        let(:Authorization) { "Bearer #{token}" }
        let(:body) { { kind: "individual", document: "000.000.000-00", name: "Bad Doc" } }
        run_test!
      end
    end
  end

  path "/api/v1/customers/{id}" do
    parameter name: :id, in: :path, type: :integer, description: "ID do cliente", example: 1

    get "Shows a customer" do
      tags "Customers"
      security [bearerAuth: []]
      produces "application/json"

      response "200", "customer found" do
        let(:Authorization) { "Bearer #{token}" }
        let(:customer)      { create(:customer) }
        let(:id)            { customer.id }
        run_test!
      end

      response "404", "customer not found" do
        let(:Authorization) { "Bearer #{token}" }
        let(:id)            { 0 }
        run_test!
      end
    end

    patch "Updates a customer" do
      tags "Customers"
      security [bearerAuth: []]
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name:  { type: :string, description: "Nome completo ou razão social", example: "João da Silva Atualizado" },
          email: { type: :string, description: "E-mail de contato",             example: "novo@email.com" },
          phone: { type: :string, description: "Telefone com DDD",              example: "11988880000" }
        },
        example: { name: "João da Silva Atualizado", phone: "11988880000" }
      }

      response "200", "customer updated" do
        let(:Authorization) { "Bearer #{token}" }
        let(:customer)      { create(:customer) }
        let(:id)            { customer.id }
        let(:body)          { { name: "Updated Name" } }
        run_test! do |response|
          expect(JSON.parse(response.body)["name"]).to eq("Updated Name")
        end
      end
    end

    delete "Soft deletes a customer" do
      tags "Customers"
      security [bearerAuth: []]

      response "204", "customer deleted" do
        let(:Authorization) { "Bearer #{token}" }
        let(:customer)      { create(:customer) }
        let(:id)            { customer.id }
        run_test!
      end
    end
  end
end
