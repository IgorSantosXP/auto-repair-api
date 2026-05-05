module Identity
  module Errors
    class AuthenticationFailed < StandardError; end
    class UserNotFound < StandardError; end
  end
end
