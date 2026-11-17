require "rails_helper"

RSpec.describe ServiceOrders::Orchestration::ServiceOrderSaga do
  let(:admin)    { create(:user) }
  let(:customer) { create(:customer) }
  let(:vehicle)  { create(:vehicle, customer: customer) }
  let(:service)  { create(:service, base_price_cents: 10_000) }
  let(:order) do
    stub_part("pastilha-freio", name: "Jogo de pastilhas", unit_price_cents: 18_000)
    ServiceOrders::UseCases::CreateOrder.call(
      { customer_id: customer.id, vehicle_id: vehicle.id, diagnosis_notes: "Barulho ao frear",
        items: [{ service_id: service.id, quantity: 1 }, { part_id: "pastilha-freio", quantity: 2 }] },
      performed_by: admin
    ).payload
  end
  let(:saga) { order.saga }

  before { allow(Identity::Services::JwtEncoder).to receive(:secret).and_return("test_secret") }

  def advance_to_payment
    deliver_event("billing.budget_generated", saga, "budget_id" => "b-1", "total_cents" => 46_000)
    deliver_event("billing.budget_approved", saga, "budget_id" => "b-1", "payment_url" => "https://pay/1")
  end

  def advance_to_execution
    advance_to_payment
    deliver_event("billing.payment_confirmed", saga, "payment_id" => "p-1", "amount_cents" => 46_000)
  end

  describe "happy path" do
    it "drives the order from received to finished" do
      deliver_event("billing.budget_generated", saga, "budget_id" => "b-1", "total_cents" => 46_000)
      expect(order.reload.status).to eq("awaiting_approval")
      expect(saga.reload).to have_attributes(state: "awaiting_approval", budget_id: "b-1")

      deliver_event("billing.budget_approved", saga, "payment_url" => "https://pay/1")
      expect(order.reload.status).to eq("awaiting_payment")
      expect(saga.reload.payment_url).to eq("https://pay/1")

      deliver_event("billing.payment_confirmed", saga, "payment_id" => "p-1")
      expect(order.reload.status).to eq("approved")
      expect(saga.reload.state).to eq("execution_requested")

      start = outbox_envelopes.last
      expect(start.type).to eq("execution.start")
      expect(start.destination).to eq("execution")
      expect(start.payload["parts"]).to eq([{ "part_id" => "pastilha-freio", "name" => "Jogo de pastilhas", "quantity" => 2 }])
      expect(start.payload["services"].first["quantity"]).to eq(1)
      expect(start.payload["notes"]).to eq("Barulho ao frear")

      deliver_event("execution.queued", saga, "position" => 1)
      expect(saga.reload.state).to eq("in_execution")

      deliver_event("execution.diagnosis_started", saga, "notes" => "ok")
      expect(order.reload.status).to eq("in_diagnosis")

      deliver_event("execution.repair_started", saga)
      expect(order.reload.status).to eq("in_execution")
      expect(order.execution_started_at).to be_present

      deliver_event("execution.finished", saga, "notes" => "pronto")
      expect(order.reload.status).to eq("finished")
      expect(order.finished_at).to be_present
      expect(saga.reload).to have_attributes(state: "completed")
      expect(saga.completed_at).to be_present
    end

    it "records every command sent and event received in the saga log" do
      advance_to_execution

      expect(saga.reload.steps.map { |s| [s.direction, s.message_type] }).to eq([
        %w[sent billing.generate_budget],
        %w[received billing.budget_generated],
        %w[received billing.budget_approved],
        %w[sent execution.start],
        %w[received billing.payment_confirmed]
      ])
    end

    it "keeps the system as the author of saga-driven transitions" do
      advance_to_payment
      expect(order.status_changes.order(:id).last).to have_attributes(performed_by: "system", event: "budget_approved")
    end
  end

  describe "compensation when execution fails (insufficient stock)" do
    before do
      advance_to_execution
      deliver_event("execution.failed", saga, "reason" => "insufficient_stock",
                                              "details" => [{ "part_id" => "pastilha-freio", "requested" => 2, "available" => 0 }])
    end

    it "asks Billing to refund the payment" do
      expect(saga.reload.state).to eq("compensating")
      expect(saga.failure_reason).to eq("execution_failed: insufficient_stock")
      refund = outbox_envelopes.last
      expect(refund.type).to eq("billing.refund_payment")
      expect(refund.destination).to eq("billing")
      expect(order.reload.status).to eq("approved")
    end

    it "cancels the order once the refund is confirmed" do
      deliver_event("billing.payment_refunded", saga, "payment_id" => "p-1", "refund_id" => "r-1")

      expect(saga.reload.state).to eq("compensated")
      expect(order.reload.status).to eq("cancelled")
      expect(order.status_changes.order(:id).last.notes).to include("r-1")
    end

    it "flags the saga when the refund fails" do
      deliver_event("billing.refund_failed", saga, "reason" => "gateway_error")

      expect(saga.reload.state).to eq("compensation_failed")
      expect(saga.failure_reason).to include("refund_failed: gateway_error")
      expect(order.reload.status).to eq("cancelled")
    end
  end

  describe "compensation when payment fails" do
    it "cancels the budget and then the order" do
      advance_to_payment
      deliver_event("billing.payment_failed", saga, "reason" => "rejected")

      expect(saga.reload.state).to eq("compensating")
      expect(outbox_types.last).to eq("billing.cancel_budget")

      deliver_event("billing.budget_cancelled", saga, "reason" => "payment_failed")
      expect(saga.reload.state).to eq("compensated")
      expect(order.reload.status).to eq("cancelled")
    end
  end

  describe "business failures" do
    it "cancels the order when the customer rejects the budget" do
      deliver_event("billing.budget_generated", saga, "budget_id" => "b-1")
      deliver_event("billing.budget_rejected", saga, "reason" => "Muito caro")

      expect(saga.reload).to have_attributes(state: "failed", failure_reason: "budget_rejected")
      expect(order.reload.status).to eq("cancelled")
    end

    it "cancels the order when the budget cannot be generated" do
      deliver_event("billing.budget_generation_failed", saga, "reason" => "invalid_total")

      expect(saga.reload.state).to eq("failed")
      expect(order.reload.status).to eq("cancelled")
    end
  end

  describe "robustness" do
    it "ignores events that do not match the current saga state" do
      expect(deliver_event("billing.payment_confirmed", saga, "payment_id" => "p-1")).to be(false)

      expect(saga.reload.state).to eq("budget_requested")
      expect(order.reload.status).to eq("received")
      expect(saga.steps.last.message_type).to eq("billing.payment_confirmed")
    end

    it "ignores events for an unknown saga" do
      envelope = Messaging::Envelope.event("billing.budget_generated", payload: {}, saga_id: "missing",
                                                                         service_order_uuid: "x")
      expect(described_class.handle(envelope)).to be(false)
    end

    it "retries execution events that arrive out of order" do
      advance_to_execution

      expect { deliver_event("execution.repair_started", saga) }.to raise_error(described_class::OutOfOrder)
      expect { deliver_event("execution.finished", saga) }.to raise_error(described_class::OutOfOrder)
      expect(order.reload.status).to eq("approved")
    end

    it "exposes a handler for every event type" do
      expect(ServiceOrders::Orchestration::Handlers::REGISTRY.keys).to match_array(described_class::EVENT_HANDLERS.keys)

      envelope = saga_event("billing.budget_generated", saga, "budget_id" => "b-9")
      ServiceOrders::Orchestration::Handlers::REGISTRY["billing.budget_generated"].call(envelope)
      expect(saga.reload.budget_id).to eq("b-9")
    end
  end
end
