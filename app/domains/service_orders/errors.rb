module ServiceOrders
  module Errors
    class NotFound                 < StandardError; end
    class InvalidTransition        < StandardError; end
    class VehicleOwnershipConflict < StandardError; end
    class PartNotFound             < StandardError; end
    class PartsCatalogUnavailable  < StandardError; end
  end
end
