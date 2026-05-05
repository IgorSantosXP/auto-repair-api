module ServiceOrders
  module Errors
    class NotFound           < StandardError; end
    class InvalidTransition  < StandardError; end
    class InvalidToken       < StandardError; end
    class TokenExpired       < StandardError; end
  end
end
