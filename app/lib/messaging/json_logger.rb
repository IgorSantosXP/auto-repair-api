module Messaging
  # Structured JSON logger for the worker process, with the same fields used by
  # lograge on the HTTP side so Datadog can correlate both.
  class JsonLogger
    def initialize(io)
      @io = io
      @io.sync = true if @io.respond_to?(:sync=)
    end

    %i[debug info warn error].each do |level|
      define_method(level) do |message, fields = {}|
        write(level, message, fields)
      end
    end

    private

    def write(level, message, fields)
      entry = {
        timestamp: Time.now.utc.iso8601(3),
        level:     level.to_s.upcase,
        service:   Messaging.service_name,
        message:   message
      }.merge(Tracing.log_correlation).merge(fields)

      @io.puts(entry.compact.to_json)
    end
  end
end
