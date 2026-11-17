module Messaging
  # Standard message exchanged between the services. Commands and events share
  # the same envelope; `kind` tells them apart and `destination` drives the SNS
  # filter policy that routes the message to a single queue.
  class Envelope
    KINDS = %w[command event].freeze

    attr_reader :message_id, :type, :kind, :source, :destination, :occurred_at,
                :saga_id, :correlation_id, :service_order_uuid, :trace, :payload

    def self.build(type:, kind:, destination:, payload:, saga_id:, service_order_uuid:, source: Messaging.service_name)
      new(
        "message_id"         => SecureRandom.uuid,
        "type"               => type,
        "kind"               => kind,
        "source"             => source,
        "destination"        => destination,
        "occurred_at"        => Time.now.utc.iso8601(3),
        "saga_id"            => saga_id,
        "correlation_id"     => saga_id,
        "service_order_uuid" => service_order_uuid,
        "trace"              => Tracing.inject,
        "payload"            => payload
      )
    end

    def self.command(type, destination:, payload:, saga_id:, service_order_uuid:)
      build(type: type, kind: "command", destination: destination, payload: payload,
            saga_id: saga_id, service_order_uuid: service_order_uuid)
    end

    def self.event(type, payload:, saga_id:, service_order_uuid:, destination: "os")
      build(type: type, kind: "event", destination: destination, payload: payload,
            saga_id: saga_id, service_order_uuid: service_order_uuid)
    end

    def self.parse(json)
      new(JSON.parse(json))
    end

    def initialize(attributes)
      attributes = attributes.transform_keys(&:to_s)

      @message_id         = attributes.fetch("message_id")
      @type               = attributes.fetch("type")
      @kind               = attributes.fetch("kind")
      @source             = attributes["source"]
      @destination        = attributes.fetch("destination")
      @occurred_at        = attributes["occurred_at"]
      @saga_id            = attributes["saga_id"]
      @correlation_id     = attributes["correlation_id"] || @saga_id
      @service_order_uuid = attributes["service_order_uuid"]
      @trace              = attributes["trace"] || {}
      @payload            = (attributes["payload"] || {}).deep_stringify_keys

      raise ArgumentError, "Unknown message kind '#{@kind}'" unless KINDS.include?(@kind)
    end

    def to_h
      {
        "message_id"         => message_id,
        "type"               => type,
        "kind"               => kind,
        "source"             => source,
        "destination"        => destination,
        "occurred_at"        => occurred_at,
        "saga_id"            => saga_id,
        "correlation_id"     => correlation_id,
        "service_order_uuid" => service_order_uuid,
        "trace"              => trace,
        "payload"            => payload
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def log_context
      {
        message_id:         message_id,
        message_type:       type,
        saga_id:            saga_id,
        correlation_id:     correlation_id,
        service_order_uuid: service_order_uuid
      }
    end
  end
end
