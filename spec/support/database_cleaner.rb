RSpec.configure do |config|
  config.before(:suite) do
    ApplicationRecord.connection_pool
    DatabaseCleaner[:active_record].clean_with(:truncation)
  end
end
