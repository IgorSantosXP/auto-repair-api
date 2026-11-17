module ServiceOrders
  module Services
    # Builds order items with a snapshot of name and price. Services come from
    # the local catalog; parts come from the Execution Service catalog.
    class ItemBuilder
      def initialize(parts_catalog:)
        @parts_catalog = parts_catalog
      end

      def build(order, items_params)
        errors = []

        items_params.each do |item_params|
          item = Entities::ServiceOrderItem.new(
            service_order_id: order.id,
            service_id:       item_params[:service_id].presence,
            part_id:          item_params[:part_id].presence&.to_s,
            quantity:         item_params[:quantity].to_i
          )
          name, price = describe(item_params)
          item.name             = name
          item.unit_price_cents = item_params[:unit_price_cents].present? ? item_params[:unit_price_cents].to_i : price

          errors.concat(item.errors.full_messages) unless item.save
        rescue ActiveRecord::RecordNotFound
          errors << "Service #{item_params[:service_id]} not found"
        rescue Errors::PartNotFound => e
          errors << e.message
        end

        errors
      end

      private

      def describe(item_params)
        if item_params[:service_id].present?
          service = Registries::Entities::Service.find(item_params[:service_id])
          [service.name, service.base_price_cents]
        elsif item_params[:part_id].present?
          part = @parts_catalog.fetch(item_params[:part_id])
          raise Errors::PartNotFound, "Part #{item_params[:part_id]} is inactive" if part["active"] == false

          [part["name"], part["unit_price_cents"].to_i]
        else
          [nil, 0]
        end
      end
    end
  end
end
