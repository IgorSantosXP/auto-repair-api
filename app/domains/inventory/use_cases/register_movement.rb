module Inventory
  module UseCases
    class RegisterMovement
      def self.call(part_id:, movement_type:, quantity:, reason:, performed_by: nil, reference_type: nil, reference_id: nil)
        unless Entities::StockMovement::TYPES.include?(movement_type)
          return Result.failure(errors: ["Invalid movement type '#{movement_type}'"])
        end

        quantity = quantity.to_i
        return Result.failure(errors: ["Quantity must be greater than 0"]) if quantity < 1

        ActiveRecord::Base.transaction do
          part = Entities::Part.lock("FOR UPDATE").find(part_id)

          if %w[outbound adjustment_out].include?(movement_type)
            balance = Services::StockBalanceCalculator.balance_for(part_id)
            if balance < quantity
              return Result.failure(errors: [
                "Insufficient stock for '#{part.name}': available #{balance}, requested #{quantity}"
              ])
            end
          end

          movement = Entities::StockMovement.create!(
            part_id:              part_id,
            movement_type:        movement_type,
            quantity:             quantity,
            reason:               reason,
            reference_type:       reference_type,
            reference_id:         reference_id,
            performed_by_user_id: performed_by&.id
          )

          Result.success(payload: movement)
        end
      rescue ActiveRecord::RecordNotFound
        Result.failure(errors: ["Part not found"])
      rescue ActiveRecord::RecordInvalid => e
        Result.failure(errors: e.record.errors.full_messages)
      end
    end
  end
end
