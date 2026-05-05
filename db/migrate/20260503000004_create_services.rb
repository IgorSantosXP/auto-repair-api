class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string  :name,                       null: false
      t.text    :description
      t.integer :base_price_cents,           null: false
      t.integer :estimated_duration_minutes
      t.boolean :active,                     null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :services, :name, unique: true,
              where: "deleted_at IS NULL", name: "index_services_on_name_active"
    add_index :services, :deleted_at
  end
end
