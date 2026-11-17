module ServiceOrders
  module Orchestration
    # Message type -> callable used by Messaging::Consumer in the OS worker.
    module Handlers
      REGISTRY = ServiceOrderSaga::EVENT_HANDLERS.keys.index_with do
        ->(envelope) { ServiceOrderSaga.handle(envelope) }
      end.freeze
    end
  end
end
