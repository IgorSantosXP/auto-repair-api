class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string   :kind,       null: false
      t.string   :document,   null: false
      t.string   :name,       null: false
      t.string   :email
      t.string   :phone
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :customers, :document, unique: true,
              where: "deleted_at IS NULL", name: "index_customers_on_document_active"
    add_index :customers, :deleted_at
  end
end
