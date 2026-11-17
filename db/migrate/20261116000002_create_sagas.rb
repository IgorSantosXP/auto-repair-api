class CreateSagas < ActiveRecord::Migration[8.1]
  STATES = %w[
    budget_requested awaiting_approval awaiting_payment execution_requested in_execution
    completed compensating compensated compensation_failed failed
  ].freeze

  def change
    create_table :sagas do |t|
      t.string     :uuid,           null: false
      t.references :service_order,  null: false, foreign_key: true, index: { unique: true }
      t.string     :state,          null: false
      t.string     :failure_reason
      t.string     :budget_id
      t.string     :payment_id
      t.string     :payment_url
      t.datetime   :completed_at
      t.timestamps
    end
    add_index :sagas, :uuid, unique: true
    add_index :sagas, :state
    add_check_constraint :sagas, "state IN (#{STATES.map { |s| "'#{s}'" }.join(', ')})", name: "chk_sagas_state"

    create_table :saga_steps do |t|
      t.references :saga,         null: false, foreign_key: true
      t.string     :direction,    null: false
      t.string     :message_type, null: false
      t.string     :message_id,   null: false
      t.string     :from_state
      t.string     :to_state
      t.jsonb      :payload,      null: false, default: {}
      t.datetime   :created_at,   null: false
    end
    add_index :saga_steps, [:saga_id, :created_at]
    add_check_constraint :saga_steps, "direction IN ('sent', 'received')", name: "chk_saga_steps_direction"
  end
end
