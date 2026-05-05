module ServiceOrders
  module UseCases
    class UpdateOrder
      EDITABLE_STATUSES = %w[received in_diagnosis].freeze

      def self.call(order_id, params, performed_by:)
        ActiveRecord::Base.transaction do
          order = Entities::ServiceOrder.find(order_id)

          unless EDITABLE_STATUSES.include?(order.status)
            return Result.failure(errors: ["Order cannot be edited in status '#{order.status}'"])
          end

          order.diagnosis_notes = params[:diagnosis_notes] if params.key?(:diagnosis_notes)

          if params[:items].present?
            order.items.destroy_all
            items_result = build_items(order, Array(params[:items]))
            return Result.failure(errors: items_result[:errors]) if items_result[:errors].any?

            order.update!(total_cents: Services::BudgetCalculator.calculate(order.items.reload))
          end

          order.save!
          Result.success(payload: order.reload)
        end
      rescue ActiveRecord::RecordNotFound
        Result.failure(errors: ["Service order not found"])
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
          errors.concat(item.errors.full_messages) unless item.save
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
