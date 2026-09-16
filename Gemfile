source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

gem "tzinfo-data", platforms: %i[ windows jruby ]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false

gem "kamal", require: false
gem "thruster", require: false

gem "json", "~> 2.21"
gem "jwt"
gem "bcrypt", "~> 3.1.7"
gem "rack-attack"

gem "rswag-api"
gem "rswag-ui"

gem "datadog", "~> 2.3"
gem "dogstatsd-ruby", "~> 5.6"
gem "lograge"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "rswag-specs"
  gem "simplecov", require: false
  gem "database_cleaner-active_record"
end
