require "webmock/rspec"

# The Datadog tracer may try to flush to a (absent) local agent.
WebMock.disable_net_connect!(allow: [%r{127\.0\.0\.1:8126}, %r{localhost:8126}])

module PartsCatalogHelpers
  EXECUTION_URL = "http://localhost:3002".freeze
  # Pin the catalog URL so specs don't depend on the shell/compose environment.
  ENV["EXECUTION_SERVICE_URL"] = EXECUTION_URL

  def stub_part(id, name: "Peça #{id}", unit_price_cents: 1_000, active: true)
    stub_request(:get, "#{EXECUTION_URL}/api/v1/parts/#{id}")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                 body: { id: id, name: name, unit_price_cents: unit_price_cents,
                         stock_quantity: 10, active: active }.to_json)
  end

  def stub_missing_part(id)
    stub_request(:get, "#{EXECUTION_URL}/api/v1/parts/#{id}")
      .to_return(status: 404, body: { error: { code: "not_found" } }.to_json)
  end
end

RSpec.configure do |config|
  config.include PartsCatalogHelpers
end
