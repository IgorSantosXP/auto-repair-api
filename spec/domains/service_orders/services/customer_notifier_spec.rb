require "rails_helper"

RSpec.describe ServiceOrders::Services::CustomerNotifier do
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:order)    { create(:service_order, customer: customer, vehicle: vehicle, status: "in_diagnosis") }

  describe ".status_changed" do
    it "e-mails the customer" do
      expect { described_class.status_changed(order) }
        .to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    it "does not e-mail when the customer has no email" do
      no_email_customer = create(:customer, email: nil)
      no_email_vehicle  = create(:vehicle, customer: no_email_customer)
      no_email_order    = create(:service_order, customer: no_email_customer, vehicle: no_email_vehicle)

      expect { described_class.status_changed(no_email_order) }
        .not_to change { ActionMailer::Base.deliveries.size }
    end

    it "stays silent on budget statuses, which Billing notifies" do
      order.update!(status: "awaiting_approval")

      expect { described_class.status_changed(order) }
        .not_to change { ActionMailer::Base.deliveries.size }
    end

    it "never raises when delivery fails" do
      allow(ServiceOrderMailer).to receive(:with).and_raise(Net::SMTPFatalError.new("boom"))

      expect(described_class.status_changed(order)).to be(false)
    end
  end
end
