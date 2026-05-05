require "rails_helper"

RSpec.describe "ApproveOrder / RejectOrder", type: :model do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:service)  { create(:service, base_price_cents: 3000) }
  let(:part)     { create(:part, unit_price_cents: 1000) }

  before do
    create(:stock_movement, part: part, performed_by_user: admin,
           movement_type: "inbound", quantity: 5)
  end

  def create_order_awaiting_approval
    result = ServiceOrders::UseCases::CreateOrder.call(
      { customer_id: customer.id, vehicle_id: vehicle.id,
        items: [{ service_id: service.id, quantity: 1 }, { part_id: part.id, quantity: 2 }] },
      performed_by: admin
    )
    order = result.payload

    ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "start_diagnosis", performed_by: admin)
    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "send_for_approval", performed_by: admin)

    { order: order.reload, token: extract_token(tr) }
  end

  def extract_token(transition_result)
    transition_result.payload[:approval_link].match(/token=(.+)$/)[1]
  end

  describe "ApproveOrder" do
    it "moves order to approved without touching stock" do
      data   = create_order_awaiting_approval
      result = ServiceOrders::UseCases::ApproveOrder.call(uuid: data[:order].uuid, token: data[:token])

      expect(result).to be_success
      expect(result.payload.status).to eq("approved")
      expect(result.payload.items.none?(&:executed)).to be true
      expect(Inventory::Services::StockBalanceCalculator.balance_for(part.id)).to eq(5)
    end

    it "resending send_for_approval invalidates old token and returns a new link" do
      data      = create_order_awaiting_approval
      old_token = data[:token]

      tr = ServiceOrders::UseCases::TransitionOrder.call(
        data[:order].id, event: "send_for_approval", performed_by: admin
      )
      expect(tr).to be_success
      new_token = tr.payload[:approval_link].match(/token=(.+)$/)[1]
      expect(new_token).not_to eq(old_token)

      expect(ServiceOrders::UseCases::ApproveOrder.call(uuid: data[:order].uuid, token: old_token)).to be_failure
      expect(ServiceOrders::UseCases::ApproveOrder.call(uuid: data[:order].uuid, token: new_token)).to be_success
    end

    it "fails with wrong token" do
      data   = create_order_awaiting_approval
      result = ServiceOrders::UseCases::ApproveOrder.call(uuid: data[:order].uuid, token: "wrong_token")

      expect(result).to be_failure
      expect(result.errors.first).to match(/Invalid or expired/)
    end

    it "fails when order is not awaiting approval" do
      order  = create(:service_order, customer: customer, vehicle: vehicle, status: "received")
      result = ServiceOrders::UseCases::ApproveOrder.call(uuid: order.uuid, token: "any")

      expect(result).to be_failure
      expect(result.errors.first).to match(/not awaiting/)
    end
  end

  describe "RejectOrder" do
    it "moves order to finished with total 0 and items not executed" do
      data   = create_order_awaiting_approval
      result = ServiceOrders::UseCases::RejectOrder.call(uuid: data[:order].uuid, token: data[:token])

      expect(result).to be_success
      expect(result.payload.status).to eq("finished")
      expect(result.payload.total_cents).to eq(0)
      expect(result.payload.items.none?(&:executed)).to be true
      expect(Inventory::Services::StockBalanceCalculator.balance_for(part.id)).to eq(5)
    end

    it "can still be delivered after rejection" do
      data   = create_order_awaiting_approval
      ServiceOrders::UseCases::RejectOrder.call(uuid: data[:order].uuid, token: data[:token])
      order  = data[:order].reload

      tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "deliver", performed_by: admin)
      expect(tr).to be_success
      expect(tr.payload[:order].status).to eq("delivered")
    end
  end
end
