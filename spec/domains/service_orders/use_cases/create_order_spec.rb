require "rails_helper"

RSpec.describe ServiceOrders::UseCases::CreateOrder do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:service)  { create(:service, base_price_cents: 5000) }
  let(:part)     { create(:part, unit_price_cents: 2000) }

  before do
    create(:stock_movement, part: part, performed_by_user: admin,
           movement_type: "inbound", quantity: 10)
  end

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

    it "calculates the total from items" do
      result = call
      expect(result.payload.total_cents).to eq(5000)
    end

    it "creates a status change record" do
      result = call
      change = result.payload.status_changes.first
      expect(change.to_status).to eq("received")
      expect(change.event).to eq("create")
    end

    it "accepts multiple items including a part" do
      result = call(items: [
        { service_id: service.id, quantity: 2 },
        { part_id:    part.id,    quantity: 1 }
      ])
      expect(result).to be_success
      expect(result.payload.total_cents).to eq(5000 * 2 + 2000)
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
