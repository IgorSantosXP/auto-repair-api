require "rails_helper"

RSpec.describe "Service Order Full Flow", type: :model do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:service)  { create(:service, base_price_cents: 8000) }
  let(:part)     { create(:part, unit_price_cents: 3000) }

  before do
    create(:stock_movement, part: part, performed_by_user: admin, movement_type: "inbound", quantity: 4)
  end

  def approval_token(transition_result)
    transition_result.payload[:approval_link].match(/token=(.+)$/)[1]
  end

  it "completes the full approved flow: received → diagnosis → awaiting → approved → in_execution → finished → delivered" do
    result = ServiceOrders::UseCases::CreateOrder.call(
      { customer_id: customer.id, vehicle_id: vehicle.id,
        items: [
          { service_id: service.id, quantity: 1 },
          { part_id: part.id, quantity: 2 }
        ] },
      performed_by: admin
    )
    expect(result).to be_success
    order = result.payload
    expect(order.status).to eq("received")
    expect(order.total_cents).to eq(8000 + 3000 * 2)
    expect(Inventory::Services::StockBalanceCalculator.balance_for(part.id)).to eq(4)

    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "start_diagnosis", performed_by: admin)
    expect(tr).to be_success
    expect(tr.payload[:order].status).to eq("in_diagnosis")

    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "send_for_approval", performed_by: admin)
    expect(tr).to be_success
    token = approval_token(tr)
    expect(token).to be_present
    expect(order.reload.status).to eq("awaiting_approval")

    approve = ServiceOrders::UseCases::ApproveOrder.call(uuid: order.uuid, token: token)
    expect(approve).to be_success
    order.reload
    expect(order.status).to eq("approved")
    expect(order.items.none?(&:executed)).to be true
    expect(Inventory::Services::StockBalanceCalculator.balance_for(part.id)).to eq(4)

    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "start_execution", performed_by: admin)
    expect(tr).to be_success
    order.reload
    expect(order.status).to eq("in_execution")
    expect(order.items.all?(&:executed)).to be true
    expect(Inventory::Services::StockBalanceCalculator.balance_for(part.id)).to eq(2)

    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "finalize", performed_by: admin)
    expect(tr).to be_success
    expect(tr.payload[:order].status).to eq("finished")

    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "deliver", performed_by: admin)
    expect(tr).to be_success
    expect(tr.payload[:order].status).to eq("delivered")

    expect(order.reload.status_changes.count).to eq(7)
    expect(order.status_changes.map(&:to_status)).to eq(
      %w[received in_diagnosis awaiting_approval approved in_execution finished delivered]
    )
  end

  it "completes the rejected flow: received → diagnosis → awaiting → finished (rejected) → delivered" do
    result = ServiceOrders::UseCases::CreateOrder.call(
      { customer_id: customer.id, vehicle_id: vehicle.id,
        items: [{ part_id: part.id, quantity: 3 }] },
      performed_by: admin
    )
    order = result.payload

    ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "start_diagnosis", performed_by: admin)
    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "send_for_approval", performed_by: admin)
    token = approval_token(tr)

    reject = ServiceOrders::UseCases::RejectOrder.call(uuid: order.uuid, token: token)
    expect(reject).to be_success
    order.reload
    expect(order.status).to eq("finished")
    expect(order.total_cents).to eq(0)
    expect(order.items.none?(&:executed)).to be true
    expect(Inventory::Services::StockBalanceCalculator.balance_for(part.id)).to eq(4)

    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "deliver", performed_by: admin)
    expect(tr).to be_success
    expect(tr.payload[:order].status).to eq("delivered")
  end

  it "blocks invalid transitions" do
    order = create(:service_order, customer: customer, vehicle: vehicle, status: "received")

    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "finalize", performed_by: admin)
    expect(tr).to be_failure
    expect(tr.errors.first).to match(/Cannot|Invalid|not allowed/i)

    tr = ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "deliver", performed_by: admin)
    expect(tr).to be_failure
  end

  it "prevents approval with an expired or wrong token" do
    result = ServiceOrders::UseCases::CreateOrder.call(
      { customer_id: customer.id, vehicle_id: vehicle.id,
        items: [{ service_id: service.id, quantity: 1 }] },
      performed_by: admin
    )
    order = result.payload
    ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "start_diagnosis", performed_by: admin)
    ServiceOrders::UseCases::TransitionOrder.call(order.id, event: "send_for_approval", performed_by: admin)

    approve = ServiceOrders::UseCases::ApproveOrder.call(uuid: order.uuid, token: "tampered_token")
    expect(approve).to be_failure
    expect(approve.errors.first).to match(/Invalid or expired/)
    expect(order.reload.status).to eq("awaiting_approval")
  end
end
