class AddPhase3ConsistencyAndPerformance < ActiveRecord::Migration[8.1]
  OPEN_STATUSES = %w[received in_diagnosis awaiting_approval approved in_execution].freeze
  ALL_STATUSES  = %w[received in_diagnosis awaiting_approval approved in_execution finished delivered].freeze

  def up
    add_index :service_orders, [:status, :created_at],
              name:  "index_service_orders_open_queue",
              where: "status NOT IN ('finished', 'delivered')"

    add_index :service_orders, [:customer_id, :created_at],
              name: "index_service_orders_on_customer_id_and_created_at"

    add_index :customers, :document, name: "index_customers_on_document"

    add_check_constraint :service_orders,
                         "status IN (#{ALL_STATUSES.map { |s| "'#{s}'" }.join(', ')})",
                         name: "chk_service_orders_status"

    add_check_constraint :service_orders, "total_cents >= 0",
                         name: "chk_service_orders_total_non_negative"

    add_check_constraint :customers, "kind IN ('individual', 'company')",
                         name: "chk_customers_kind"

    add_check_constraint :stock_movements,
                         "movement_type IN ('inbound', 'outbound', 'adjustment_in', 'adjustment_out')",
                         name: "chk_stock_movements_type"

    add_check_constraint :vehicles, "year BETWEEN 1900 AND 2100",
                         name: "chk_vehicles_year_range"

    add_check_constraint :service_order_items, "unit_price_cents >= 0 AND total_cents >= 0",
                         name: "chk_service_order_items_prices_non_negative"

    add_check_constraint :parts, "unit_price_cents >= 0",
                         name: "chk_parts_price_non_negative"

    add_check_constraint :services, "base_price_cents >= 0",
                         name: "chk_services_price_non_negative"
  end

  def down
    remove_check_constraint :services, name: "chk_services_price_non_negative"
    remove_check_constraint :parts, name: "chk_parts_price_non_negative"
    remove_check_constraint :service_order_items, name: "chk_service_order_items_prices_non_negative"
    remove_check_constraint :vehicles, name: "chk_vehicles_year_range"
    remove_check_constraint :stock_movements, name: "chk_stock_movements_type"
    remove_check_constraint :customers, name: "chk_customers_kind"
    remove_check_constraint :service_orders, name: "chk_service_orders_total_non_negative"
    remove_check_constraint :service_orders, name: "chk_service_orders_status"

    remove_index :customers, name: "index_customers_on_document"
    remove_index :service_orders, name: "index_service_orders_on_customer_id_and_created_at"
    remove_index :service_orders, name: "index_service_orders_open_queue"
  end
end
