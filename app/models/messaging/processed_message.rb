module Messaging
  class ProcessedMessage < ApplicationRecord
    self.table_name = "processed_messages"

    validates :message_id, presence: true
  end
end
