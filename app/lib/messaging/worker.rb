module Messaging
  # Worker process: relays the outbox on a background thread and consumes the
  # service queue on the main one. Started with `bin/rails messaging:work`.
  class Worker
    def initialize(consumer:, relay: -> { Outbox.relay }, relay_interval: 1.0)
      @consumer       = consumer
      @relay          = relay
      @relay_interval = relay_interval
      @stopping       = false
    end

    def start
      trap_signals
      Messaging.logger.info("Worker started", queue_url: Messaging.queue_url)

      relay_thread = Thread.new { relay_loop }
      @consumer.run(stop: -> { @stopping })
      relay_thread.join
      Messaging.logger.info("Worker stopped")
    end

    private

    def relay_loop
      until @stopping
        Rails.application.executor.wrap { @relay.call }
        sleep @relay_interval
      end
    rescue StandardError => e
      Messaging.logger.error("Outbox relay crashed", error: e.class.name, error_message: e.message)
      sleep @relay_interval
      retry unless @stopping
    end

    def trap_signals
      %w[INT TERM].each { |signal| Signal.trap(signal) { @stopping = true } }
    end
  end
end
