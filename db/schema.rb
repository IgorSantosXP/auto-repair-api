# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_03_000009) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "customers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "document", null: false
    t.string "email"
    t.string "kind", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_customers_on_deleted_at"
    t.index ["document"], name: "index_customers_on_document_active", unique: true, where: "(deleted_at IS NULL)"
  end

  create_table "parts", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name", null: false
    t.string "sku", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_parts_on_deleted_at"
    t.index ["sku"], name: "index_parts_on_sku_active", unique: true, where: "(deleted_at IS NULL)"
  end

  create_table "service_order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "executed", default: false, null: false
    t.bigint "part_id"
    t.integer "quantity", null: false
    t.bigint "service_id"
    t.bigint "service_order_id", null: false
    t.integer "total_cents", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["part_id"], name: "index_service_order_items_on_part_id"
    t.index ["service_id"], name: "index_service_order_items_on_service_id"
    t.index ["service_order_id"], name: "index_service_order_items_on_service_order_id"
    t.check_constraint "quantity > 0", name: "chk_item_quantity"
    t.check_constraint "service_id IS NOT NULL AND part_id IS NULL OR service_id IS NULL AND part_id IS NOT NULL", name: "chk_item_has_one_ref"
  end

  create_table "service_order_status_changes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event", null: false
    t.string "from_status"
    t.text "notes"
    t.string "performed_by", null: false
    t.bigint "performed_by_user_id"
    t.bigint "service_order_id", null: false
    t.string "to_status", null: false
    t.index ["performed_by_user_id"], name: "index_service_order_status_changes_on_performed_by_user_id"
    t.index ["service_order_id", "created_at"], name: "idx_on_service_order_id_created_at_a694840dff"
    t.index ["service_order_id"], name: "index_service_order_status_changes_on_service_order_id"
  end

  create_table "service_orders", force: :cascade do |t|
    t.string "approval_token_digest"
    t.datetime "approval_token_expires_at"
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.text "diagnosis_notes"
    t.datetime "execution_started_at"
    t.datetime "finished_at"
    t.string "status", default: "received", null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.bigint "vehicle_id", null: false
    t.index ["customer_id"], name: "index_service_orders_on_customer_id"
    t.index ["status"], name: "index_service_orders_on_status"
    t.index ["uuid"], name: "index_service_orders_on_uuid", unique: true
    t.index ["vehicle_id"], name: "index_service_orders_on_vehicle_id"
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "base_price_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.integer "estimated_duration_minutes"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_services_on_deleted_at"
    t.index ["name"], name: "index_services_on_name_active", unique: true, where: "(deleted_at IS NULL)"
  end

  create_table "stock_movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "movement_type", null: false
    t.bigint "part_id", null: false
    t.bigint "performed_by_user_id"
    t.integer "quantity", null: false
    t.string "reason"
    t.bigint "reference_id"
    t.string "reference_type"
    t.index ["part_id", "created_at"], name: "index_stock_movements_on_part_id_and_created_at"
    t.index ["part_id"], name: "index_stock_movements_on_part_id"
    t.index ["performed_by_user_id"], name: "index_stock_movements_on_performed_by_user_id"
    t.index ["reference_type", "reference_id"], name: "index_stock_movements_on_reference_type_and_reference_id"
    t.check_constraint "quantity > 0", name: "chk_quantity_positive"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "brand", null: false
    t.datetime "created_at", null: false
    t.bigint "customer_id", null: false
    t.datetime "deleted_at"
    t.string "license_plate", null: false
    t.string "model", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["customer_id"], name: "index_vehicles_on_customer_id"
    t.index ["deleted_at"], name: "index_vehicles_on_deleted_at"
    t.index ["license_plate"], name: "index_vehicles_on_license_plate_active", unique: true, where: "(deleted_at IS NULL)"
  end

  add_foreign_key "service_order_items", "parts"
  add_foreign_key "service_order_items", "service_orders"
  add_foreign_key "service_order_items", "services"
  add_foreign_key "service_order_status_changes", "service_orders"
  add_foreign_key "service_order_status_changes", "users", column: "performed_by_user_id"
  add_foreign_key "service_orders", "customers"
  add_foreign_key "service_orders", "vehicles"
  add_foreign_key "stock_movements", "parts"
  add_foreign_key "stock_movements", "users", column: "performed_by_user_id"
  add_foreign_key "vehicles", "customers"
end
