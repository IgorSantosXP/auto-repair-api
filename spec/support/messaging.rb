# In-memory replacement for the SNS bus and helpers to drive the saga in tests.
class FakeBus
  attr_reader :published

  def initialize
    @published = []
  end

  def publish(envelope)
    @published << envelope
  end
end

module MessagingHelpers
  def outbox_envelopes
    Messaging::OutboxMessage.order(:id).map(&:envelope)
  end

  def outbox_types
    outbox_envelopes.map(&:type)
  end

  def saga_event(type, saga, payload = {})
    Messaging::Envelope.event(type, payload: payload, saga_id: saga.uuid,
                                    service_order_uuid: saga.service_order.uuid)
  end

  def deliver_event(type, saga, payload = {})
    ServiceOrders::Orchestration::ServiceOrderSaga.handle(saga_event(type, saga, payload))
  end
end

RSpec.configure do |config|
  config.include MessagingHelpers

  config.before do
    Messaging.logger = Messaging::JsonLogger.new(StringIO.new)
    Messaging.bus    = FakeBus.new
  end
end
