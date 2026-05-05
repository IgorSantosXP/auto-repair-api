class CreateParts < ActiveRecord::Migration[8.1]
  def change
    create_table :parts do |t|
      t.string  :sku,              null: false
      t.string  :name,             null: false
      t.text    :description
      t.integer :unit_price_cents, null: false
      t.boolean :active,           null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :parts, :sku, unique: true,
              where: "deleted_at IS NULL", name: "index_parts_on_sku_active"
    add_index :parts, :deleted_at
  end
end
