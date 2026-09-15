Rails.application.configure do
  config.lograge.enabled               = true
  config.lograge.base_controller_class = "ActionController::API"
  config.lograge.formatter             = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    payload = event.payload

    fields = {
      timestamp:  Time.current.iso8601,
      env:        Rails.env,
      service:    ENV.fetch("DD_SERVICE", "auto-repair-api"),
      request_id: payload[:request_id],
      remote_ip:  payload[:remote_ip],
      params:     payload[:params]&.except("controller", "action", "format", "password"),
      exception:  payload[:exception]&.first
    }

    if defined?(Datadog::Tracing)
      correlation = Datadog::Tracing.correlation
      fields["dd.trace_id"] = correlation.trace_id.to_s
      fields["dd.span_id"]  = correlation.span_id.to_s
    end

    fields.compact
  end
end
