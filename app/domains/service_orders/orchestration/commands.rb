module ServiceOrders
  module Orchestration
    # Payload builders for the commands the orchestrator sends. Each command
    # carries everything the receiving service needs, so no service has to
    # query the OS database.
    module Commands
      module_function

      def generate_budget(order)
        customer = order.customer
        {
          "customer" => {
            "id"       => customer.id.to_s,
            "name"     => customer.name,
            "email"    => customer.email,
            "document" => customer.document
          },
          "vehicle"  => vehicle(order),
          "items"    => order.items.map do |item|
            {
              "kind"             => item.kind,
              "reference_id"     => item.reference_id,
              "name"             => item.name,
              "quantity"         => item.quantity,
              "unit_price_cents" => item.unit_price_cents
            }
          end
        }
      end

      def start_execution(order)
        services, parts = order.items.partition { |item| item.kind == "service" }
        {
          "vehicle"  => vehicle(order),
          "services" => services.map { |item| { "name" => item.name, "quantity" => item.quantity } },
          "parts"    => parts.map { |item| { "part_id" => item.part_id, "name" => item.name, "quantity" => item.quantity } },
          "notes"    => order.diagnosis_notes
        }
      end

      def vehicle(order)
        vehicle = order.vehicle
        {
          "license_plate" => vehicle.license_plate,
          "brand"         => vehicle.brand,
          "model"         => vehicle.model,
          "year"          => vehicle.year
        }
      end
    end
  end
end
