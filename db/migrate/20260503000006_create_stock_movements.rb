class CreateStockMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_movements do |t|
      t.references :part,               null: false, foreign_key: true
      t.string     :movement_type,      null: false
      t.integer    :quantity,           null: false
      t.string     :reason
      t.string     :reference_type
      t.bigint     :reference_id
      t.references :performed_by_user,  null: true, foreign_key: { to_table: :users }
      t.datetime   :created_at,         null: false
    end

    add_index :stock_movements, %i[part_id created_at]
    add_index :stock_movements, %i[reference_type reference_id]

    reversible do |dir|
      dir.up do
        execute "ALTER TABLE stock_movements ADD CONSTRAINT chk_quantity_positive CHECK (quantity > 0)"
      end
    end
  end
end
