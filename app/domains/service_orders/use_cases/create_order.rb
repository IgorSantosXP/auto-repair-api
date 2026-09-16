module ServiceOrders
  module UseCases
    class CreateOrder
      def self.call(params, performed_by:)
        ActiveRecord::Base.transaction do
          customer = resolve_customer(params)
          vehicle  = resolve_vehicle(params, customer)

          order = Entities::ServiceOrder.new(
            customer_id:     customer&.id,
            vehicle_id:      vehicle&.id,
            status:          "received",
            diagnosis_notes: params[:diagnosis_notes]
          )

          unless order.valid?
            Telemetry.order_processing_failed(stage: "creation", reason: "invalid_order")
            return Result.failure(errors: order.errors.full_messages)
          end

          order.save!

          items = build_items(order, Array(params[:items]))
          if items[:errors].any?
            Telemetry.order_processing_failed(stage: "creation", reason: "invalid_items")
            return Result.failure(errors: items[:errors])
          end

          order.update!(total_cents: Services::BudgetCalculator.calculate(order.items.reload))

          Entities::ServiceOrderStatusChange.create!(
            service_order_id:     order.id,
            from_status:          nil,
            to_status:            "received",
            event:                "create",
            performed_by_user_id: performed_by.id,
            performed_by:         "admin"
          )

          Telemetry.order_created(order)

          Result.success(payload: order.reload)
        end
      rescue ActiveRecord::RecordInvalid => e
        Telemetry.order_processing_failed(stage: "creation", reason: "invalid_record")
        Result.failure(errors: e.record.errors.full_messages)
      rescue Errors::VehicleOwnershipConflict => e
        Telemetry.order_processing_failed(stage: "creation", reason: "vehicle_ownership_conflict")
        Result.failure(errors: [e.message])
      end

      private_class_method def self.resolve_customer(params)
        return Registries::Entities::Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?

        attrs = params[:customer]
        return nil if attrs.blank?

        document = normalize_document(attrs)
        Registries::Entities::Customer.find_by(document: document) ||
          Registries::Entities::Customer.create!(attrs.to_h.merge(document: document))
      end

      private_class_method def self.resolve_vehicle(params, customer)
        return Registries::Entities::Vehicle.find_by(id: params[:vehicle_id]) if params[:vehicle_id].present?

        attrs = params[:vehicle]
        return nil if attrs.blank? || customer.nil?

        plate    = Registries::ValueObjects::LicensePlate.new(attrs[:license_plate]).normalized
        existing = Registries::Entities::Vehicle.find_by(license_plate: plate)

        if existing
          unless existing.customer_id == customer.id
            raise Errors::VehicleOwnershipConflict, "License plate #{plate} is registered to another customer"
          end
          existing
        else
          Registries::Entities::Vehicle.create!(attrs.to_h.merge(customer_id: customer.id))
        end
      end

      private_class_method def self.normalize_document(attrs)
        document = attrs[:document]
        return document if document.blank?

        if attrs[:kind] == "company"
          Registries::ValueObjects::Cnpj.new(document).normalized
        else
          Registries::ValueObjects::Cpf.new(document).normalized
        end
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
