# Phase 4: parts/stock moved to the Execution Service and budget approval to
# the Billing Service. Items keep a snapshot of the name and price, and part_id
# becomes the Execution Service's string identifier (no foreign key anymore).
class SplitInventoryAndBillingOutOfOs < ActiveRecord::Migration[8.1]
  OLD_STATUSES = %w[received in_diagnosis awaiting_approval approved in_execution finished delivered].freeze
  NEW_STATUSES = %w[received awaiting_approval awaiting_payment approved in_diagnosis in_execution finished delivered cancelled].freeze

  def up
    add_column :service_order_items, :name, :string

    execute <<~SQL
      UPDATE service_order_items i SET name = s.name FROM services s WHERE i.service_id = s.id;
      UPDATE service_order_items i SET name = p.name FROM parts p WHERE i.part_id = p.id;
      UPDATE service_order_items SET name = 'Item' WHERE name IS NULL;
    SQL
    change_column_null :service_order_items, :name, false

    remove_foreign_key :service_order_items, :parts
    change_column :service_order_items, :part_id, :string

    drop_table :stock_movements
    drop_table :parts

    remove_column :service_orders, :approval_token_digest
    remove_column :service_orders, :approval_token_expires_at

    replace_status_constraint(NEW_STATUSES)

    remove_index :service_orders, name: "index_service_orders_open_queue"
    add_index :service_orders, [:status, :created_at], name: "index_service_orders_open_queue",
              where: "status NOT IN ('finished', 'delivered', 'cancelled')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def replace_status_constraint(statuses)
    remove_check_constraint :service_orders, name: "chk_service_orders_status"
    add_check_constraint :service_orders, "status IN (#{statuses.map { |s| "'#{s}'" }.join(', ')})",
                         name: "chk_service_orders_status"
  end
end
