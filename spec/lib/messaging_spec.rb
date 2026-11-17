require "rails_helper"

RSpec.describe Messaging do
  let(:log_io) { StringIO.new }
  let(:logs)   { log_io.string.lines.map { |line| JSON.parse(line) } }

  before { Messaging.logger = Messaging::JsonLogger.new(log_io) }

  def envelope(type = "billing.budget_generated", payload: { "budget_id" => "b-1" })
    Messaging::Envelope.event(type, payload: payload, saga_id: "saga-1", service_order_uuid: "os-1")
  end

  def sqs_message(body, receipt: "r-1")
    Aws::SQS::Types::Message.new(body: body, receipt_handle: receipt)
  end

  describe "module configuration" do
    around do |example|
      keys     = %w[AWS_ENDPOINT_URL AWS_REGION SERVICE_NAME AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY]
      original = ENV.to_h.slice(*keys)
      # Static credentials keep the SDK from probing the EC2 metadata endpoint on CI runners.
      ENV["AWS_ACCESS_KEY_ID"]     = "test"
      ENV["AWS_SECRET_ACCESS_KEY"] = "test"
      example.run
    ensure
      keys.each { |key| ENV[key] = original[key] }
      Messaging.reset!
    end

    it "points the AWS clients to the configured endpoint" do
      ENV["AWS_ENDPOINT_URL"] = "http://localstack:4566"
      ENV["AWS_REGION"]       = "sa-east-1"

      expect(Messaging.client_options).to eq(region: "sa-east-1", endpoint: "http://localstack:4566")
      expect(Messaging.sns).to be_a(Aws::SNS::Client)
      expect(Messaging.sqs).to be_a(Aws::SQS::Client)
    end

    it "omits the endpoint in AWS" do
      ENV.delete("AWS_ENDPOINT_URL")
      expect(Messaging.client_options).not_to have_key(:endpoint)
    end

    it "builds a default bus after a reset" do
      Messaging.reset!
      expect(Messaging.bus).to be_a(Messaging::Bus)
    end
  end

  describe Messaging::Envelope do
    it "round-trips through JSON" do
      original = envelope
      parsed   = described_class.parse(original.to_json)

      expect(parsed.to_h).to eq(original.to_h)
      expect(parsed.kind).to eq("event")
      expect(parsed.destination).to eq("os")
      expect(parsed.correlation_id).to eq("saga-1")
    end

    it "builds commands with a destination" do
      command = described_class.command("execution.start", destination: "execution", payload: { a: 1 },
                                                           saga_id: "s", service_order_uuid: "o")
      expect(command).to have_attributes(kind: "command", destination: "execution", payload: { "a" => 1 })
      expect(command.log_context).to include(message_type: "execution.start", saga_id: "s")
    end

    it "rejects unknown kinds" do
      expect { described_class.new(envelope.to_h.merge("kind" => "query")) }.to raise_error(ArgumentError)
    end
  end

  describe Messaging::Bus do
    let(:sns) { Aws::SNS::Client.new(stub_responses: true) }

    it "publishes the envelope with routing attributes" do
      described_class.new(client: sns, topic_arn: "arn:topic").publish(envelope)

      request = sns.api_requests.last
      expect(request[:operation_name]).to eq(:publish)
      expect(request[:params][:topic_arn]).to eq("arn:topic")
      expect(request[:params][:message_attributes]["destination"][:string_value]).to eq("os")
      expect(JSON.parse(request[:params][:message])["type"]).to eq("billing.budget_generated")
      expect(logs.last).to include("message" => "Message published", "destination" => "os")
    end
  end

  describe Messaging::Outbox do
    it "publishes pending messages once, in order" do
      bus    = FakeBus.new
      first  = envelope("billing.budget_generated")
      second = envelope("billing.budget_approved")
      described_class.enqueue(first)
      described_class.enqueue(second)

      expect(described_class.relay(bus: bus)).to eq(2)
      expect(bus.published.map(&:message_id)).to eq([first.message_id, second.message_id])
      expect(described_class.relay(bus: bus)).to eq(0)
      expect(Messaging::OutboxMessage.pending).to be_empty
    end
  end

  describe Messaging::DatabaseIdempotency do
    subject(:idempotency) { described_class.new }

    it "runs the block once per message id" do
      calls = 0
      expect(idempotency.once("m-1") { calls += 1 }).to be(true)
      expect(idempotency.once("m-1") { calls += 1 }).to be(false)
      expect(calls).to eq(1)
    end

    it "does not record the message when the handler fails" do
      expect { idempotency.once("m-2") { raise "boom" } }.to raise_error("boom")
      expect(Messaging::ProcessedMessage.where(message_id: "m-2")).to be_empty
    end
  end

  describe Messaging::Consumer do
    let(:sqs)      { Aws::SQS::Client.new(stub_responses: true) }
    let(:received) { [] }
    let(:handlers) { { "billing.budget_generated" => ->(env) { received << env.message_id } } }
    let(:consumer) do
      described_class.new(handlers: handlers, idempotency: Messaging::DatabaseIdempotency.new,
                          queue_url: "http://queue", client: sqs, wait_time_seconds: 0)
    end

    def deleted_receipts
      sqs.api_requests.select { |r| r[:operation_name] == :delete_message }.map { |r| r[:params][:receipt_handle] }
    end

    it "dispatches each message and deletes it after success" do
      message = envelope
      sqs.stub_responses(:receive_message, messages: [{ body: message.to_json, receipt_handle: "r-1" }])

      expect(consumer.poll_once).to eq(1)
      expect(received).to eq([message.message_id])
      expect(deleted_receipts).to eq(["r-1"])
      expect(logs.last).to include("message" => "Message consumed", "saga_id" => "saga-1")
    end

    it "ignores duplicates but still deletes them" do
      message = envelope
      2.times { |i| consumer.process(sqs_message(message.to_json, receipt: "r-#{i}")) }

      expect(received.size).to eq(1)
      expect(deleted_receipts).to eq(%w[r-0 r-1])
      expect(logs.last["message"]).to eq("Duplicate message ignored")
    end

    it "discards messages without a handler" do
      consumer.process(sqs_message(envelope("unknown.type").to_json))

      expect(deleted_receipts).to eq(["r-1"])
      expect(logs.last["message"]).to eq("No handler for message type, discarding")
    end

    it "keeps failed messages on the queue for retry" do
      failing = described_class.new(handlers: { "billing.budget_generated" => ->(_) { raise "boom" } },
                                    idempotency: Messaging::DatabaseIdempotency.new,
                                    queue_url: "http://queue", client: sqs)

      expect(failing.process(sqs_message(envelope.to_json))).to be(false)
      expect(deleted_receipts).to be_empty
      expect(logs.last).to include("level" => "ERROR", "error_message" => "boom")
    end

    it "survives unparseable bodies" do
      expect(consumer.process(sqs_message("not json"))).to be(false)
      expect(deleted_receipts).to be_empty
    end

    it "polls until told to stop" do
      sqs.stub_responses(:receive_message, messages: [])
      polls = 0
      consumer.run(stop: -> { (polls += 1) > 2 })
      expect(sqs.api_requests.count { |r| r[:operation_name] == :receive_message }).to eq(2)
    end
  end

  describe Messaging::Provisioner do
    let(:sns) { Aws::SNS::Client.new(stub_responses: true) }
    let(:sqs) { Aws::SQS::Client.new(stub_responses: true) }

    around do |example|
      original = ENV.to_h.slice("EVENTS_TOPIC_ARN", "QUEUE_URL")
      example.run
    ensure
      %w[EVENTS_TOPIC_ARN QUEUE_URL].each { |key| ENV[key] = original[key] }
    end

    it "creates the topic, queue, DLQ and filtered subscription" do
      allow(Messaging).to receive_messages(sns: sns, sqs: sqs)
      sns.stub_responses(:create_topic, topic_arn: "arn:topic")
      sqs.stub_responses(:create_queue, [{ queue_url: "http://dlq" }, { queue_url: "http://queue" }])
      sqs.stub_responses(:get_queue_attributes, ->(ctx) { { attributes: { "QueueArn" => "arn:#{ctx.params[:queue_url]}" } } })

      result = described_class.new(destination: "os", topic_name: "events", queue_name: "os-queue").call

      expect(result).to eq(topic_arn: "arn:topic", queue_url: "http://queue")
      expect(ENV.fetch("QUEUE_URL")).to eq("http://queue")
      subscribe = sns.api_requests.find { |r| r[:operation_name] == :subscribe }[:params]
      expect(JSON.parse(subscribe[:attributes]["FilterPolicy"])).to eq("destination" => ["os"])
      queue = sqs.api_requests.select { |r| r[:operation_name] == :create_queue }.last[:params]
      expect(JSON.parse(queue[:attributes]["RedrivePolicy"])).to eq("deadLetterTargetArn" => "arn:http://dlq", "maxReceiveCount" => 3)
    end
  end

  describe Messaging::Worker do
    it "relays the outbox and consumes until a stop signal" do
      relays   = 0
      consumer = Object.new
      worker   = described_class.new(consumer: consumer, relay: -> { relays += 1 }, relay_interval: 0.01)
      consumer.define_singleton_method(:run) do |stop:|
        sleep 0.05
        worker.instance_variable_set(:@stopping, true)
        stop.call
      end
      allow(Messaging).to receive(:queue_url).and_return("http://queue")
      allow(Signal).to receive(:trap)

      worker.start

      expect(relays).to be >= 1
      expect(logs.map { |l| l["message"] }).to include("Worker started", "Worker stopped")
    end

    it "keeps relaying after an error" do
      attempts = 0
      worker = described_class.new(consumer: nil, relay_interval: 0, relay: lambda {
        attempts += 1
        raise "db down" if attempts == 1

        worker.instance_variable_set(:@stopping, true)
      })

      worker.send(:relay_loop)

      expect(attempts).to eq(2)
      expect(logs.first).to include("message" => "Outbox relay crashed", "error_message" => "db down")
    end
  end

  describe Messaging::Tracing do
    it "is a no-op when tracing is disabled" do
      allow(Datadog::Tracing).to receive(:enabled?).and_return(false)

      expect(described_class.inject).to eq({})
      expect(described_class.log_correlation).to eq({})
      expect(described_class.continue(envelope) { :ran }).to eq(:ran)
    end

    it "continues the trace from the envelope when enabled" do
      allow(Datadog::Tracing).to receive(:enabled?).and_return(true)

      result = described_class.continue(envelope) { |span| span.name }
      expect(result).to eq("messaging.consume")
      expect(described_class.inject).to be_a(Hash)
      expect(described_class.log_correlation).to be_a(Hash)
    end
  end
end
