module Messaging
  # Propagates the Datadog trace through the message envelope so a saga shows up
  # as a single distributed trace across the three services.
  module Tracing
    module_function

    def enabled?
      defined?(Datadog::Tracing) && Datadog::Tracing.enabled?
    end

    def inject
      return {} unless enabled?

      digest = Datadog::Tracing.active_trace&.to_digest
      return {} if digest.nil?

      headers = {}
      Datadog::Tracing::Contrib::HTTP.inject(digest, headers)
      headers
    rescue StandardError
      {}
    end

    def continue(envelope, &block)
      return yield unless enabled?

      digest = Datadog::Tracing::Contrib::HTTP.extract(envelope.trace || {})
      Datadog::Tracing.trace(
        "messaging.consume",
        service:       Messaging.service_name,
        resource:      envelope.type,
        continue_from: digest,
        tags:          {
          "saga.id"                 => envelope.saga_id,
          "service_order.uuid"      => envelope.service_order_uuid,
          "messaging.message_id"    => envelope.message_id,
          "messaging.source"        => envelope.source
        }.compact,
        &block
      )
    end

    def log_correlation
      return {} unless enabled?

      correlation = Datadog::Tracing.correlation
      return {} if correlation.trace_id.to_s == "0"

      { "dd.trace_id" => correlation.trace_id.to_s, "dd.span_id" => correlation.span_id.to_s }
    end
  end
end
