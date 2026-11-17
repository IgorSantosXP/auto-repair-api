namespace :messaging do
  desc "Run the OS worker: outbox relay + saga event consumer"
  task work: :environment do
    if ENV["MESSAGING_AUTO_PROVISION"] == "true"
      Messaging::Provisioner.new(
        destination: "os",
        topic_name:  ENV.fetch("EVENTS_TOPIC_NAME", "auto-repair-local-events"),
        queue_name:  ENV.fetch("QUEUE_NAME", "auto-repair-local-os")
      ).call
    end

    consumer = Messaging::Consumer.new(
      handlers:    ServiceOrders::Orchestration::Handlers::REGISTRY,
      idempotency: Messaging::DatabaseIdempotency.new
    )
    Messaging::Worker.new(consumer: consumer).start
  end
end
