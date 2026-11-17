require "rails_helper"

RSpec.describe "Admin order use cases" do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }

  describe ServiceOrders::UseCases::DeliverOrder do
    it "delivers a finished order and records the admin in the history" do
      order = create(:service_order, customer: customer, vehicle: vehicle, status: "finished")

      result = described_class.call(order.id, performed_by: admin)

      expect(result).to be_success
      expect(result.payload.status).to eq("delivered")
      change = order.status_changes.last
      expect(change).to have_attributes(event: "deliver", performed_by: "admin", performed_by_user_id: admin.id)
    end

    it "refuses to deliver an order that is not finished" do
      order = create(:service_order, customer: customer, vehicle: vehicle, status: "in_execution")

      result = described_class.call(order.id, performed_by: admin)

      expect(result).to be_failure
      expect(result.errors.first).to match(/Cannot 'deliver' from 'in_execution'/)
    end

    it "fails for an unknown order" do
      expect(described_class.call(0, performed_by: admin).errors).to eq(["Service order not found"])
    end
  end

  describe ServiceOrders::UseCases::UpdateOrder do
    let(:order) { create(:service_order, customer: customer, vehicle: vehicle, status: "in_diagnosis") }

    it "updates the diagnosis notes" do
      result = described_class.call(order.id, { diagnosis_notes: "Disco empenado" }, performed_by: admin)

      expect(result).to be_success
      expect(result.payload.diagnosis_notes).to eq("Disco empenado")
    end

    it "does not allow changing items after the budget was requested" do
      result = described_class.call(order.id, { items: [{ service_id: 1, quantity: 1 }] }, performed_by: admin)

      expect(result).to be_failure
    end

    it "does not allow editing a terminal order" do
      order.update!(status: "cancelled")

      expect(described_class.call(order.id, { diagnosis_notes: "x" }, performed_by: admin)).to be_failure
    end

    it "fails for an unknown order" do
      expect(described_class.call(0, {}, performed_by: admin)).to be_failure
    end
  end
end
