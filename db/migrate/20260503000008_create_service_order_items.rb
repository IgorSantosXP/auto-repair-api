class CreateServiceOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :service_order_items do |t|
      t.references :service_order,    null: false, foreign_key: true
      t.references :service,          null: true,  foreign_key: true
      t.references :part,             null: true,  foreign_key: true
      t.integer    :quantity,         null: false
      t.integer    :unit_price_cents, null: false
      t.integer    :total_cents,      null: false
      t.boolean    :executed,         null: false, default: false
      t.timestamps
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE service_order_items
            ADD CONSTRAINT chk_item_has_one_ref
            CHECK (
              (service_id IS NOT NULL AND part_id IS NULL) OR
              (service_id IS NULL     AND part_id IS NOT NULL)
            )
        SQL
        execute "ALTER TABLE service_order_items ADD CONSTRAINT chk_item_quantity CHECK (quantity > 0)"
      end
    end
  end
end
