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
end
