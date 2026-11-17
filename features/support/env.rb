ENV["RAILS_ENV"] ||= "test"
ENV["DISABLE_BOOTSNAP"] = "1"

require "cucumber/rails"
require "rack/test"
require "webmock/cucumber"
require "factory_bot_rails"

WebMock.disable_net_connect!(allow: [%r{127\.0\.0\.1:8126}, %r{localhost:8126}])
ENV["EXECUTION_SERVICE_URL"] = "http://localhost:3002"

ActionController::Base.allow_rescue = false
DatabaseCleaner.strategy = :transaction
Cucumber::Rails::Database.javascript_strategy = :truncation

World(FactoryBot::Syntax::Methods)
World(Rack::Test::Methods)

module ApiWorld
  def app
    Rails.application
  end

  def json
    JSON.parse(last_response.body)
  end
end
World(ApiWorld)

Before do
  ActionMailer::Base.deliveries.clear
  Messaging.logger = Messaging::JsonLogger.new(StringIO.new)
  allow_jwt_secret = "cucumber_secret"
  Identity::Services::JwtEncoder.singleton_class.send(:define_method, :secret) { allow_jwt_secret }
end
