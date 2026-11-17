module Telemetry
  NAMESPACE = "auto_repair".freeze

  module_function

  def enabled?
    ENV["DD_AGENT_HOST"].present?
  end

  def client
    return nil unless enabled?

    @client ||= Datadog::Statsd.new(
      ENV.fetch("DD_AGENT_HOST"),
      ENV.fetch("DD_DOGSTATSD_PORT", "8125").to_i,
      namespace: NAMESPACE,
      tags: base_tags
    )
  end

  def base_tags
    [
      "env:#{ENV.fetch('DD_ENV', Rails.env)}",
      "service:#{ENV.fetch('DD_SERVICE', 'auto-repair-api')}"
    ]
  end

  def order_created(order)
    increment("service_order.created", tags: ["status:#{order.status}"])
  end

  def status_transition(from:, to:, event:, duration_seconds:)
    increment("service_order.status_changed", tags: ["from:#{from}", "to:#{to}", "event:#{event}"])
    distribution("service_order.status_duration", duration_seconds, tags: ["status:#{from}"])
  end

  def order_processing_failed(stage:, reason:)
    increment("service_order.failed", tags: ["stage:#{stage}", "reason:#{reason}"])
  end

  def integration_error(integration:, reason:)
    increment("integration.error", tags: ["integration:#{integration}", "reason:#{reason}"])
  end

  def saga_started
    increment("saga.started")
  end

  def saga_step(type:, direction:)
    increment("saga.step", tags: ["type:#{type}", "direction:#{direction}"])
  end

  def saga_completed(duration_seconds:)
    increment("saga.completed")
    distribution("saga.duration", duration_seconds)
  end

  def saga_failed(reason:)
    increment("saga.failed", tags: ["reason:#{reason.to_s.split(':').first}"])
  end

  def saga_compensating(reason:)
    increment("saga.compensating", tags: ["reason:#{reason.to_s.split(':').first}"])
  end

  def saga_compensated(reason:)
    increment("saga.compensated", tags: ["reason:#{reason.to_s.split(':').first}"])
  end

  def saga_compensation_failed(reason:)
    increment("saga.compensation_failed", tags: ["reason:#{reason}"])
  end

  def increment(metric, tags: [])
    client&.increment(metric, tags: base_tags + tags)
  rescue StandardError => e
    Rails.logger.warn("[Telemetry] Failed to emit #{metric}: #{e.message}")
  end

  def distribution(metric, value, tags: [])
    client&.distribution(metric, value, tags: base_tags + tags)
  rescue StandardError => e
    Rails.logger.warn("[Telemetry] Failed to emit #{metric}: #{e.message}")
  end
end
