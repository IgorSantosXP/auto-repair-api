RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do |example|
    DatabaseCleaner.strategy = example.metadata[:type] == :request ? :truncation : :transaction
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end
end
