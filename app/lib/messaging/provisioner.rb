module Messaging
  # Local development only (MESSAGING_AUTO_PROVISION=true): creates the topic,
  # the service queue, its DLQ and the filtered subscription on LocalStack.
  # In AWS these resources come from Terraform.
  class Provisioner
    def initialize(destination:, topic_name:, queue_name:)
      @destination = destination
      @topic_name  = topic_name
      @queue_name  = queue_name
    end

    def call
      topic_arn = Messaging.sns.create_topic(name: @topic_name).topic_arn
      dlq_url   = Messaging.sqs.create_queue(queue_name: "#{@queue_name}-dlq").queue_url
      dlq_arn   = queue_arn(dlq_url)

      queue_url = Messaging.sqs.create_queue(
        queue_name: @queue_name,
        attributes: {
          "VisibilityTimeout" => "30",
          "RedrivePolicy"     => { deadLetterTargetArn: dlq_arn, maxReceiveCount: 3 }.to_json
        }
      ).queue_url

      Messaging.sns.subscribe(
        topic_arn:  topic_arn,
        protocol:   "sqs",
        endpoint:   queue_arn(queue_url),
        attributes: {
          "RawMessageDelivery" => "true",
          "FilterPolicy"       => { destination: [@destination] }.to_json
        }
      )

      ENV["EVENTS_TOPIC_ARN"] = topic_arn
      ENV["QUEUE_URL"]        = queue_url
      Messaging.logger.info("Local messaging provisioned", topic_arn: topic_arn, queue_url: queue_url)

      { topic_arn: topic_arn, queue_url: queue_url }
    end

    private

    def queue_arn(url)
      Messaging.sqs.get_queue_attributes(queue_url: url, attribute_names: ["QueueArn"]).attributes["QueueArn"]
    end
  end
end
