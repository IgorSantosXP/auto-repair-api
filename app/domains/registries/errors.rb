module Registries
  module Errors
    class NotFound         < StandardError; end
    class InvalidDocument  < StandardError; end
    class InvalidPlate     < StandardError; end
    class AlreadyDeleted   < StandardError; end
  end
end
