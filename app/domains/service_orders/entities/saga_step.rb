module ServiceOrders
  module Entities
    class SagaStep < ApplicationRecord
      self.table_name = "saga_steps"

      belongs_to :saga, class_name: "ServiceOrders::Entities::Saga"

      validates :direction, inclusion: { in: %w[sent received] }
      validates :message_type, :message_id, presence: true

      def as_json(_options = {})
        {
          "direction"    => direction,
          "message_type" => message_type,
          "message_id"   => message_id,
          "from_state"   => from_state,
          "to_state"     => to_state,
          "payload"      => payload,
          "at"           => created_at
        }
      end
    end
  end
end
