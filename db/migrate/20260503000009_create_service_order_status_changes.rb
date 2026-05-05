class CreateServiceOrderStatusChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :service_order_status_changes do |t|
      t.references :service_order,     null: false, foreign_key: true
      t.string     :from_status
      t.string     :to_status,         null: false
      t.string     :event,             null: false
      t.references :performed_by_user, null: true,  foreign_key: { to_table: :users }
      t.string     :performed_by,      null: false
      t.text       :notes
      t.datetime   :created_at,        null: false
    end

    add_index :service_order_status_changes, %i[service_order_id created_at]
  end
end
