class CreateVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicles do |t|
      t.references :customer, null: false, foreign_key: true
      t.string     :license_plate, null: false
      t.string     :brand,         null: false
      t.string     :model,         null: false
      t.integer    :year,          null: false
      t.datetime   :deleted_at
      t.timestamps
    end

    add_index :vehicles, :license_plate, unique: true,
              where: "deleted_at IS NULL", name: "index_vehicles_on_license_plate_active"
    add_index :vehicles, :deleted_at
  end
end
