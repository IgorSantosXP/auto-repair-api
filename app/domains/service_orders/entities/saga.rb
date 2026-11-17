module ServiceOrders
  module Entities
    # Saga log of the orchestrator: current state of the distributed
    # transaction for one service order plus every command sent and event
    # received (see SagaStep).
    class Saga < ApplicationRecord
      self.table_name = "sagas"

      STATES = %w[
        budget_requested awaiting_approval awaiting_payment execution_requested in_execution
        completed compensating compensated compensation_failed failed
      ].freeze

      FINAL_STATES = %w[completed compensated compensation_failed failed].freeze

      belongs_to :service_order, class_name: "ServiceOrders::Entities::ServiceOrder"
      has_many   :steps, -> { order(:created_at, :id) },
                 class_name: "ServiceOrders::Entities::SagaStep", foreign_key: :saga_id, dependent: :destroy

      validates :uuid,  presence: true, uniqueness: true
      validates :state, inclusion: { in: STATES }

      before_validation { self.uuid ||= SecureRandom.uuid }

      def final?
        FINAL_STATES.include?(state)
      end

      def as_json(_options = {})
        {
          "id"                 => uuid,
          "service_order_uuid" => service_order.uuid,
          "state"              => state,
          "failure_reason"     => failure_reason,
          "budget_id"          => budget_id,
          "payment_id"         => payment_id,
          "payment_url"        => payment_url,
          "completed_at"       => completed_at,
          "created_at"         => created_at,
          "steps"              => steps.map(&:as_json)
        }
      end
    end
  end
end
