require "rails_helper"

RSpec.describe ServiceOrders::Queries::ListOrdersQuery do
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }

  def create_order(status, created_at: Time.current)
    create(:service_order, customer: customer, vehicle: vehicle, status: status, created_at: created_at)
  end

  describe ".call" do
    it "orders by status priority: in_execution > awaiting_approval > in_diagnosis > received" do
      received          = create_order("received")
      in_execution      = create_order("in_execution")
      in_diagnosis      = create_order("in_diagnosis")
      awaiting_approval = create_order("awaiting_approval")

      expect(described_class.call.to_a).to eq([in_execution, awaiting_approval, in_diagnosis, received])
    end

    it "ranks approved orders right below in_execution" do
      awaiting_approval = create_order("awaiting_approval")
      approved          = create_order("approved")
      in_execution      = create_order("in_execution")

      expect(described_class.call.to_a).to eq([in_execution, approved, awaiting_approval])
    end

    it "orders oldest first within the same status" do
      newer = create_order("received", created_at: 1.hour.ago)
      older = create_order("received", created_at: 3.days.ago)

      expect(described_class.call.to_a).to eq([older, newer])
    end

    it "excludes finished and delivered orders by default" do
      active = create_order("received")
      create_order("finished")
      create_order("delivered")

      expect(described_class.call.to_a).to eq([active])
    end

    it "keeps finished orders in the database" do
      finished = create_order("finished")

      expect(ServiceOrders::Entities::ServiceOrder.find(finished.id)).to be_present
    end

    it "returns finished orders when explicitly filtered by status" do
      finished = create_order("finished")
      create_order("received")

      expect(described_class.call(status: "finished").to_a).to eq([finished])
    end

    it "filters by customer_id" do
      other_customer = create(:customer)
      other_vehicle  = create(:vehicle, customer: other_customer)
      mine           = create_order("received")
      create(:service_order, customer: other_customer, vehicle: other_vehicle, status: "received")

      expect(described_class.call(customer_id: customer.id).to_a).to eq([mine])
    end

    it "filters by creation date range" do
      create_order("received", created_at: 10.days.ago)
      recent = create_order("received", created_at: 1.day.ago)

      result = described_class.call(from: 2.days.ago.to_date, to: Date.current)

      expect(result.to_a).to eq([recent])
    end
  end
end
