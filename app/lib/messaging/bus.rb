module Messaging
  # Publishes envelopes to the shared SNS topic. The `destination` attribute is
  # matched by each queue's filter policy, so a message reaches exactly one service.
  class Bus
    def initialize(client: nil, topic_arn: nil)
      @client    = client
      @topic_arn = topic_arn
    end

    def publish(envelope)
      client.publish(
        topic_arn:          topic_arn,
        message:            envelope.to_json,
        message_attributes: {
          "type"        => { data_type: "String", string_value: envelope.type },
          "destination" => { data_type: "String", string_value: envelope.destination }
        }
      )

      Telemetry.increment("messaging.published", tags: ["type:#{envelope.type}"])
      Messaging.logger.info("Message published", envelope.log_context.merge(destination: envelope.destination))
    end

    private

    def client
      @client ||= Messaging.sns
    end

    def topic_arn
      @topic_arn ||= Messaging.topic_arn
    end
  end
end
