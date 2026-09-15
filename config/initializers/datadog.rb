return unless ENV["DD_AGENT_HOST"].present?

require "datadog"
require "datadog/statsd"

Datadog.configure do |c|
  c.service = ENV.fetch("DD_SERVICE", "auto-repair-api")
  c.env     = ENV.fetch("DD_ENV", Rails.env)
  c.version = ENV.fetch("DD_VERSION", "unknown")

  c.agent.host = ENV.fetch("DD_AGENT_HOST")
  c.agent.port = ENV.fetch("DD_TRACE_AGENT_PORT", "8126").to_i

  c.tracing.enabled = true
  c.tracing.instrument :rails, service_name: ENV.fetch("DD_SERVICE", "auto-repair-api")
  c.tracing.instrument :pg
  c.tracing.instrument :active_support
  c.tracing.instrument :action_mailer

  c.runtime_metrics.enabled = true
end
