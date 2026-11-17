module Messaging
  # Runs the handler and records the message id in the same transaction, so a
  # redelivered message is skipped and a failed handler leaves no trace.
  class DatabaseIdempotency
    def once(message_id)
      ProcessedMessage.transaction(requires_new: true) do
        ProcessedMessage.create!(message_id: message_id)
        yield
      end
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end
  end
end
