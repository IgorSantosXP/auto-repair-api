require "aws-sdk-sns"
require "aws-sdk-sqs"

# Thin messaging layer over Amazon SNS (publish) and SQS (consume).
# Locally it talks to LocalStack through AWS_ENDPOINT_URL.
module Messaging
  module_function

  def service_name
    ENV.fetch("SERVICE_NAME", "os-service")
  end

  def topic_arn
    ENV.fetch("EVENTS_TOPIC_ARN")
  end

  def queue_url
    ENV.fetch("QUEUE_URL")
  end

  def client_options
    options = { region: ENV.fetch("AWS_REGION", "us-east-1") }
    options[:endpoint] = ENV["AWS_ENDPOINT_URL"] if ENV["AWS_ENDPOINT_URL"].present?
    options
  end

  def sns
    @sns ||= Aws::SNS::Client.new(client_options)
  end

  def sqs
    @sqs ||= Aws::SQS::Client.new(client_options)
  end

  def bus
    @bus ||= Bus.new
  end

  def bus=(bus)
    @bus = bus
  end

  def logger
    @logger ||= JsonLogger.new($stdout)
  end

  def logger=(logger)
    @logger = logger
  end

  def reset!
    @sns = @sqs = @bus = nil
  end
end
