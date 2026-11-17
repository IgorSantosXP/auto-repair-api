module Messaging
  # Transactional outbox: messages are written in the same database
  # transaction as the state change that produced them and published to SNS
  # afterwards by the relay, so a crash never leaves the saga half-notified.
  class OutboxMessage < ApplicationRecord
    self.table_name = "outbox_messages"

    scope :pending, -> { where(published_at: nil) }

    validates :message_id, :message_type, :destination, :body, presence: true

    def self.enqueue(envelope)
      create!(
        message_id:   envelope.message_id,
        message_type: envelope.type,
        destination:  envelope.destination,
        body:         envelope.to_h
      )
    end

    def envelope
      Envelope.new(body)
    end
  end
end
