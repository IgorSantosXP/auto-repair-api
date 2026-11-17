module ServiceOrders
  module UseCases
    # Opens a service order and starts the saga in the same transaction: the
    # `billing.generate_budget` command is written to the outbox together with
    # the order, so either both exist or neither does.
    class CreateOrder
      def self.call(params, performed_by:, parts_catalog: nil)
        parts_catalog ||= Gateways::PartsCatalog.new(
          auth_token: Identity::Services::JwtEncoder.encode({ "sub" => performed_by.id })
        )

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

          if Array(params[:items]).empty?
            Telemetry.order_processing_failed(stage: "creation", reason: "no_items")
            return Result.failure(errors: ["Order must have at least one item"])
          end

          order.save!

          errors = Services::ItemBuilder.new(parts_catalog: parts_catalog).build(order, Array(params[:items]))
          if errors.any?
            Telemetry.order_processing_failed(stage: "creation", reason: "invalid_items")
            raise ItemsInvalid.new(errors)
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

          Orchestration::ServiceOrderSaga.start(order)
          Telemetry.order_created(order)

          Result.success(payload: order.reload)
        end
      rescue ItemsInvalid => e
        Result.failure(errors: e.errors)
      rescue ActiveRecord::RecordInvalid => e
        Telemetry.order_processing_failed(stage: "creation", reason: "invalid_record")
        Result.failure(errors: e.record.errors.full_messages)
      rescue Errors::VehicleOwnershipConflict => e
        Telemetry.order_processing_failed(stage: "creation", reason: "vehicle_ownership_conflict")
        Result.failure(errors: [e.message])
      rescue Errors::PartsCatalogUnavailable => e
        Telemetry.order_processing_failed(stage: "creation", reason: "parts_catalog_unavailable")
        Result.failure(errors: [e.message], status: :service_unavailable)
      end

      class ItemsInvalid < StandardError
        attr_reader :errors

        def initialize(errors)
          @errors = errors
          super(errors.join(", "))
        end
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
    end
  end
end
