require "rails_helper"

RSpec.describe ServiceOrders::Services::CustomerNotifier do
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:order)    { create(:service_order, customer: customer, vehicle: vehicle) }

  describe ".status_changed" do
    it "enqueues a status changed email for the customer" do
      expect { described_class.status_changed(order) }
        .to have_enqueued_mail(ServiceOrderMailer, :status_changed)
    end

    it "does not enqueue when the customer has no email" do
      no_email_customer = create(:customer, email: nil)
      no_email_vehicle  = create(:vehicle, customer: no_email_customer)
      no_email_order    = create(:service_order, customer: no_email_customer, vehicle: no_email_vehicle)

      expect { described_class.status_changed(no_email_order) }
        .not_to have_enqueued_mail(ServiceOrderMailer, :status_changed)
    end
  end
end
