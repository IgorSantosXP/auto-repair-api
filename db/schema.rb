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

ActiveRecord::Schema[8.1].define(version: 2026_11_16_000003) do
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
    t.index ["document"], name: "index_customers_on_document"
    t.index ["document"], name: "index_customers_on_document_active", unique: true, where: "(deleted_at IS NULL)"
    t.check_constraint "kind::text = ANY (ARRAY['individual'::character varying::text, 'company'::character varying::text])", name: "chk_customers_kind"
  end

  create_table "outbox_messages", force: :cascade do |t|
    t.jsonb "body", null: false
    t.datetime "created_at", null: false
    t.string "destination", null: false
    t.string "message_id", null: false
    t.string "message_type", null: false
    t.datetime "published_at"
    t.datetime "updated_at", null: false
    t.index ["id"], name: "index_outbox_messages_pending", where: "(published_at IS NULL)"
    t.index ["message_id"], name: "index_outbox_messages_on_message_id", unique: true
  end

  create_table "processed_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_id", null: false
    t.index ["message_id"], name: "index_processed_messages_on_message_id", unique: true
  end

  create_table "saga_steps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.string "from_state"
    t.string "message_id", null: false
    t.string "message_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.bigint "saga_id", null: false
    t.string "to_state"
    t.index ["saga_id", "created_at"], name: "index_saga_steps_on_saga_id_and_created_at"
    t.index ["saga_id"], name: "index_saga_steps_on_saga_id"
    t.check_constraint "direction::text = ANY (ARRAY['sent'::character varying, 'received'::character varying]::text[])", name: "chk_saga_steps_direction"
  end

  create_table "sagas", force: :cascade do |t|
    t.string "budget_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "failure_reason"
    t.string "payment_id"
    t.string "payment_url"
    t.bigint "service_order_id", null: false
    t.string "state", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["service_order_id"], name: "index_sagas_on_service_order_id", unique: true
    t.index ["state"], name: "index_sagas_on_state"
    t.index ["uuid"], name: "index_sagas_on_uuid", unique: true
    t.check_constraint "state::text = ANY (ARRAY['budget_requested'::character varying, 'awaiting_approval'::character varying, 'awaiting_payment'::character varying, 'execution_requested'::character varying, 'in_execution'::character varying, 'completed'::character varying, 'compensating'::character varying, 'compensated'::character varying, 'compensation_failed'::character varying, 'failed'::character varying]::text[])", name: "chk_sagas_state"
  end

  create_table "service_order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "executed", default: false, null: false
    t.string "name", null: false
    t.string "part_id"
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
    t.check_constraint "unit_price_cents >= 0 AND total_cents >= 0", name: "chk_service_order_items_prices_non_negative"
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
    t.index ["customer_id", "created_at"], name: "index_service_orders_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_service_orders_on_customer_id"
    t.index ["status", "created_at"], name: "index_service_orders_open_queue", where: "((status)::text <> ALL ((ARRAY['finished'::character varying, 'delivered'::character varying, 'cancelled'::character varying])::text[]))"
    t.index ["status"], name: "index_service_orders_on_status"
    t.index ["uuid"], name: "index_service_orders_on_uuid", unique: true
    t.index ["vehicle_id"], name: "index_service_orders_on_vehicle_id"
    t.check_constraint "status::text = ANY (ARRAY['received'::character varying, 'awaiting_approval'::character varying, 'awaiting_payment'::character varying, 'approved'::character varying, 'in_diagnosis'::character varying, 'in_execution'::character varying, 'finished'::character varying, 'delivered'::character varying, 'cancelled'::character varying]::text[])", name: "chk_service_orders_status"
    t.check_constraint "total_cents >= 0", name: "chk_service_orders_total_non_negative"
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
    t.check_constraint "base_price_cents >= 0", name: "chk_services_price_non_negative"
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
    t.check_constraint "year >= 1900 AND year <= 2100", name: "chk_vehicles_year_range"
  end

  add_foreign_key "saga_steps", "sagas"
  add_foreign_key "sagas", "service_orders"
  add_foreign_key "service_order_items", "service_orders"
  add_foreign_key "service_order_items", "services"
  add_foreign_key "service_order_status_changes", "service_orders"
  add_foreign_key "service_order_status_changes", "users", column: "performed_by_user_id"
  add_foreign_key "service_orders", "customers"
  add_foreign_key "service_orders", "vehicles"
  add_foreign_key "vehicles", "customers"
end
