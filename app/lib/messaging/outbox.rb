module Messaging
  module Outbox
    module_function

    def enqueue(envelope)
      OutboxMessage.enqueue(envelope)
    end

    # Publishes pending messages in insertion order. SKIP LOCKED lets several
    # worker replicas relay concurrently without publishing the same row twice.
    def relay(batch_size: 50, bus: Messaging.bus)
      published = 0

      OutboxMessage.transaction do
        OutboxMessage.pending.order(:id).limit(batch_size).lock("FOR UPDATE SKIP LOCKED").each do |message|
          bus.publish(message.envelope)
          message.update!(published_at: Time.current)
          published += 1
        end
      end

      published
    end
  end
end
