# bootsnap 1.23 crashes if loaded while SimpleCov is active (Ruby >= 3.4.10)
ENV["DISABLE_BOOTSNAP"] = "1"

require "simplecov"

SimpleCov.start "rails" do
  minimum_coverage 80 unless ARGV.include?("--dry-run")
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/vendor/"

  add_group "Domains",     "app/domains"
  add_group "Controllers", "app/controllers"
  add_group "Lib",         "app/lib"
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
