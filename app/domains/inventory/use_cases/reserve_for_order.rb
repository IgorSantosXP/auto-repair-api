module Inventory
  module UseCases
    class ReserveForOrder
      def self.call(order_items:, service_order_id:, performed_by: nil)
        part_items = order_items.select(&:part_id)
        return Result.success if part_items.empty?

        errors = []

        ActiveRecord::Base.transaction do
          part_items.each do |item|
            result = RegisterMovement.call(
              part_id:        item.part_id,
              movement_type:  "outbound",
              quantity:       item.quantity,
              reason:         "service_order",
              performed_by:   performed_by,
              reference_type: "ServiceOrder",
              reference_id:   service_order_id
            )

            unless result.success?
              errors.concat(result.errors)
              raise ActiveRecord::Rollback
            end
          end
        end

        errors.empty? ? Result.success : Result.failure(errors: errors)
      end
    end
  end
end
