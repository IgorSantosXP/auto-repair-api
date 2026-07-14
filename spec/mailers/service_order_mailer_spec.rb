require "rails_helper"

RSpec.describe ServiceOrderMailer, type: :mailer do
  describe "#status_changed" do
    let(:customer) { create(:customer, name: "John Doe", email: "john@example.com") }
    let(:vehicle)  { create(:vehicle, customer: customer) }
    let(:order)    { create(:service_order, customer: customer, vehicle: vehicle, status: "in_diagnosis") }

    it "sends to the customer email with order and status in the subject" do
      mail = described_class.with(order: order).status_changed

      expect(mail.to).to eq(["john@example.com"])
      expect(mail.subject).to include(order.uuid)
      expect(mail.subject).to include("In diagnosis")
    end

    it "greets the customer and mentions the vehicle" do
      mail = described_class.with(order: order).status_changed

      expect(mail.body.encoded).to include("John Doe")
      expect(mail.body.encoded).to include(vehicle.license_plate)
    end

    it "includes approval and rejection links when present" do
      approve = "http://localhost:3000/api/v1/customer/service_orders/#{order.uuid}/approve?token=abc123"
      reject  = "http://localhost:3000/api/v1/customer/service_orders/#{order.uuid}/reject?token=abc123"
      mail    = described_class.with(order: order, approval_link: approve, rejection_link: reject).status_changed

      expect(mail.body.encoded).to include(approve)
      expect(mail.body.encoded).to include(reject)
    end

    it "omits approval instructions when no link is given" do
      mail = described_class.with(order: order).status_changed

      expect(mail.body.encoded).not_to include("Approve the budget")
    end
  end
end
