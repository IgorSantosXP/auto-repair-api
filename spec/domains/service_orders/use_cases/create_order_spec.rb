require "rails_helper"

RSpec.describe ServiceOrders::UseCases::CreateOrder do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:service)  { create(:service, name: "Troca de óleo", base_price_cents: 5000) }

  before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

  def call(overrides = {})
    described_class.call({
      customer_id: customer.id,
      vehicle_id:  vehicle.id,
      items: [
        { service_id: service.id, quantity: 1 }
      ]
    }.merge(overrides), performed_by: admin)
  end

  describe ".call" do
    it "creates an order with status received" do
      result = call
      expect(result).to be_success
      expect(result.payload.status).to eq("received")
      expect(result.payload.uuid).to be_present
    end

    it "calculates the total from items and snapshots the name" do
      result = call
      expect(result.payload.total_cents).to eq(5000)
      expect(result.payload.items.first.name).to eq("Troca de óleo")
    end

    it "creates a status change record" do
      result = call
      change = result.payload.status_changes.first
      expect(change.to_status).to eq("received")
      expect(change.event).to eq("create")
    end

    it "starts the saga and writes the generate_budget command to the outbox" do
      result = call
      saga   = result.payload.saga

      expect(saga.state).to eq("budget_requested")
      expect(outbox_types).to eq(["billing.generate_budget"])

      command = outbox_envelopes.first
      expect(command.destination).to eq("billing")
      expect(command.saga_id).to eq(saga.uuid)
      expect(command.service_order_uuid).to eq(result.payload.uuid)
      expect(command.payload["customer"]["id"]).to eq(customer.id.to_s)
      expect(command.payload["items"].first).to include("kind" => "service", "unit_price_cents" => 5000)
    end

    it "prices parts through the Execution Service catalog" do
      stub_part("oleo-5w30", name: "Óleo 5W30 1L", unit_price_cents: 4500)

      result = call(items: [
        { service_id: service.id, quantity: 2 },
        { part_id: "oleo-5w30", quantity: 3 }
      ])

      expect(result).to be_success
      expect(result.payload.total_cents).to eq(5000 * 2 + 4500 * 3)
      part_item = result.payload.items.find { |item| item.part_id == "oleo-5w30" }
      expect(part_item.name).to eq("Óleo 5W30 1L")
      expect(a_request(:get, "http://localhost:3002/api/v1/parts/oleo-5w30")
               .with(headers: { "Authorization" => /\ABearer .+/ })).to have_been_made
    end

    it "fails and rolls back when a part does not exist" do
      stub_missing_part("nope")

      result = nil
      expect { result = call(items: [{ part_id: "nope", quantity: 1 }]) }
        .not_to change(ServiceOrders::Entities::ServiceOrder, :count)

      expect(result).to be_failure
      expect(result.errors.first).to match(/not found/)
      expect(Messaging::OutboxMessage.count).to eq(0)
    end

    it "rejects inactive parts" do
      stub_part("old", active: false)

      result = call(items: [{ part_id: "old", quantity: 1 }])

      expect(result).to be_failure
      expect(result.errors.first).to match(/inactive/)
    end

    it "fails when the parts catalog is unavailable" do
      stub_request(:get, %r{/api/v1/parts/}).to_return(status: 503)

      result = call(items: [{ part_id: "oleo-5w30", quantity: 1 }])

      expect(result).to be_failure
      expect(result.errors.first).to match(/unavailable/)
    end

    it "fails for an unknown service" do
      result = call(items: [{ service_id: 0, quantity: 1 }])
      expect(result).to be_failure
    end

    it "requires at least one item" do
      result = call(items: [])
      expect(result).to be_failure
      expect(result.errors).to include("Order must have at least one item")
    end

    it "returns failure for missing customer" do
      result = call(customer_id: 0)
      expect(result).to be_failure
    end

    it "returns failure for items with neither service nor part" do
      result = call(items: [{ quantity: 1 }])
      expect(result).to be_failure
    end
  end

  describe ".call with customer and vehicle data" do
    let(:customer_data) do
      { kind: "individual", document: "529.982.247-25", name: "Maria Silva",
        email: "maria@example.com", phone: "11 99999-0000" }
    end
    let(:vehicle_data) do
      { license_plate: "abc-1234", brand: "Fiat", model: "Uno", year: 2018 }
    end

    def call_with_data(overrides = {})
      described_class.call({
        customer: customer_data,
        vehicle:  vehicle_data,
        items:    [{ service_id: service.id, quantity: 1 }]
      }.merge(overrides), performed_by: admin)
    end

    it "creates customer and vehicle when they do not exist" do
      result = call_with_data

      expect(result).to be_success
      expect(result.payload.customer.document).to eq("52998224725")
      expect(result.payload.vehicle.license_plate).to eq("ABC1234")
    end

    it "reuses an existing customer found by document" do
      existing = create(:customer, document: "52998224725")

      result = call_with_data

      expect(result).to be_success
      expect(result.payload.customer_id).to eq(existing.id)
      expect(Registries::Entities::Customer.where(document: "52998224725").count).to eq(1)
    end

    it "reuses an existing vehicle of the same customer found by plate" do
      existing_customer = create(:customer, document: "52998224725")
      existing_vehicle  = create(:vehicle, customer: existing_customer, license_plate: "ABC1234")

      result = call_with_data

      expect(result).to be_success
      expect(result.payload.vehicle_id).to eq(existing_vehicle.id)
    end

    it "fails when the plate belongs to another customer" do
      create(:vehicle, customer: create(:customer), license_plate: "ABC1234")

      result = call_with_data

      expect(result).to be_failure
      expect(result.errors.first).to match(/registered to another customer/)
    end

    it "fails with invalid customer document" do
      result = call_with_data(customer: customer_data.merge(document: "111.111.111-11"))

      expect(result).to be_failure
    end
  end
end
