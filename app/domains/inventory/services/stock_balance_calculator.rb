module Inventory
  module Services
    class StockBalanceCalculator
      def self.balance_for(part_id)
        Entities::StockMovement
          .where(part_id: part_id)
          .sum(<<~SQL.squish)
            CASE movement_type
              WHEN 'inbound'       THEN quantity
              WHEN 'adjustment_in' THEN quantity
              ELSE -quantity
            END
          SQL
      end

      def self.balance_for_locked(part_id)
        Entities::Part.lock("FOR UPDATE").find(part_id)
        balance_for(part_id)
      end
    end
  end
end
