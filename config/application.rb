require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module AutoRepairApi
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.api_only = true

    config.autoload_paths += [Rails.root.join("app/domains")]
    config.autoload_paths += [Rails.root.join("app/lib")]

    config.eager_load_paths += [Rails.root.join("app/domains")]
    config.eager_load_paths += [Rails.root.join("app/lib")]
  end
end
