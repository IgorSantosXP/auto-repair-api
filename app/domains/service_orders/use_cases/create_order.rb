module ServiceOrders
  module UseCases
    class CreateOrder
      def self.call(params, performed_by:)
        ActiveRecord::Base.transaction do
          order = Entities::ServiceOrder.new(
            customer_id:     params[:customer_id],
            vehicle_id:      params[:vehicle_id],
            status:          "received",
            diagnosis_notes: params[:diagnosis_notes]
          )

          unless order.valid?
            return Result.failure(errors: order.errors.full_messages)
          end

          order.save!

          items = build_items(order, Array(params[:items]))
          return Result.failure(errors: items[:errors]) if items[:errors].any?

          order.update!(total_cents: Services::BudgetCalculator.calculate(order.items.reload))

          Entities::ServiceOrderStatusChange.create!(
            service_order_id:     order.id,
            from_status:          nil,
            to_status:            "received",
            event:                "create",
            performed_by_user_id: performed_by.id,
            performed_by:         "admin"
          )

          Result.success(payload: order.reload)
        end
      rescue ActiveRecord::RecordInvalid => e
        Result.failure(errors: e.record.errors.full_messages)
      end

      private_class_method def self.build_items(order, items_params)
        errors = []

        items_params.each do |item_params|
          price = resolve_price(item_params)
          item  = Entities::ServiceOrderItem.new(
            service_order_id: order.id,
            service_id:       item_params[:service_id],
            part_id:          item_params[:part_id],
            quantity:         item_params[:quantity].to_i,
            unit_price_cents: price
          )

          unless item.save
            errors.concat(item.errors.full_messages)
          end
        end

        { errors: errors }
      end

      private_class_method def self.resolve_price(item_params)
        return item_params[:unit_price_cents].to_i if item_params[:unit_price_cents].present?

        if item_params[:service_id].present?
          Registries::Entities::Service.find(item_params[:service_id]).base_price_cents
        elsif item_params[:part_id].present?
          Inventory::Entities::Part.find(item_params[:part_id]).unit_price_cents
        else
          0
        end
      end
    end
  end
end
