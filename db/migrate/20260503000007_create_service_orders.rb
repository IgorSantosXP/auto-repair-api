class CreateServiceOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :service_orders do |t|
      t.string     :uuid,                     null: false
      t.references :customer,                 null: false, foreign_key: true
      t.references :vehicle,                  null: false, foreign_key: true
      t.string     :status,                   null: false, default: "received"
      t.text       :diagnosis_notes
      t.integer    :total_cents,              null: false, default: 0
      t.string     :approval_token_digest
      t.datetime   :approval_token_expires_at
      t.datetime   :execution_started_at
      t.datetime   :finished_at
      t.timestamps
    end

    add_index :service_orders, :uuid,   unique: true
    add_index :service_orders, :status
  end
end
