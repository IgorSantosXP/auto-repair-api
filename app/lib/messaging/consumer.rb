module Messaging
  # Long-polls the service queue and dispatches each envelope to the handler
  # registered for its type. A message is deleted only after the handler
  # succeeds; failures are left on the queue, retried after the visibility
  # timeout and moved to the DLQ by SQS after maxReceiveCount attempts.
  class Consumer
    def initialize(handlers:, idempotency:, queue_url: nil, client: nil, wait_time_seconds: 10)
      @handlers          = handlers
      @idempotency       = idempotency
      @queue_url         = queue_url
      @client            = client
      @wait_time_seconds = wait_time_seconds
    end

    def run(stop: -> { false })
      poll_once until stop.call
    end

    def poll_once
      response = client.receive_message(
        queue_url:               queue_url,
        max_number_of_messages:  10,
        wait_time_seconds:       @wait_time_seconds,
        message_attribute_names: ["All"]
      )

      response.messages.each { |message| process(message) }
      response.messages.size
    end

    def process(sqs_message)
      envelope = Envelope.parse(sqs_message.body)
      handler  = @handlers[envelope.type]

      if handler.nil?
        Messaging.logger.warn("No handler for message type, discarding", envelope.log_context)
        return delete(sqs_message)
      end

      Rails.application.executor.wrap do
        Tracing.continue(envelope) do
          processed = @idempotency.once(envelope.message_id) { handler.call(envelope) }
          log_processed(envelope, processed)
        end
      end

      delete(sqs_message)
      true
    rescue StandardError => e
      Telemetry.increment("messaging.failed", tags: ["type:#{envelope&.type || 'unparseable'}"])
      Messaging.logger.error(
        "Message processing failed",
        (envelope&.log_context || {}).merge(error: e.class.name, error_message: e.message)
      )
      false
    end

    private

    def log_processed(envelope, processed)
      if processed
        Telemetry.increment("messaging.consumed", tags: ["type:#{envelope.type}"])
        Messaging.logger.info("Message consumed", envelope.log_context)
      else
        Messaging.logger.info("Duplicate message ignored", envelope.log_context)
      end
    end

    def delete(sqs_message)
      client.delete_message(queue_url: queue_url, receipt_handle: sqs_message.receipt_handle)
    end

    def client
      @client ||= Messaging.sqs
    end

    def queue_url
      @queue_url ||= Messaging.queue_url
    end
  end
end
