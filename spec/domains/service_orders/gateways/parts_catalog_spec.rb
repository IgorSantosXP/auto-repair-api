require "rails_helper"

RSpec.describe ServiceOrders::Gateways::PartsCatalog do
  subject(:catalog) { described_class.new(auth_token: "tok", base_url: "http://execution:3000/") }

  let(:url) { "http://execution:3000/api/v1/parts/oleo-5w30" }

  it "returns the part and forwards the bearer token" do
    stub_request(:get, url).with(headers: { "Authorization" => "Bearer tok" })
                           .to_return(status: 200, body: { id: "oleo-5w30", name: "Óleo", unit_price_cents: 4500 }.to_json)

    expect(catalog.fetch("oleo-5w30")).to include("name" => "Óleo", "unit_price_cents" => 4500)
  end

  it "raises PartNotFound on 404" do
    stub_request(:get, url).to_return(status: 404)

    expect { catalog.fetch("oleo-5w30") }.to raise_error(ServiceOrders::Errors::PartNotFound)
  end

  it "raises PartsCatalogUnavailable on server errors and emits a metric" do
    stub_request(:get, url).to_return(status: 500)
    expect(Telemetry).to receive(:integration_error).with(integration: "execution_service", reason: "http_500")

    expect { catalog.fetch("oleo-5w30") }.to raise_error(ServiceOrders::Errors::PartsCatalogUnavailable)
  end

  it "raises PartsCatalogUnavailable on timeouts" do
    stub_request(:get, url).to_timeout

    expect { catalog.fetch("oleo-5w30") }.to raise_error(ServiceOrders::Errors::PartsCatalogUnavailable)
  end

  it "raises PartsCatalogUnavailable on invalid JSON" do
    stub_request(:get, url).to_return(status: 200, body: "<html>")

    expect { catalog.fetch("oleo-5w30") }.to raise_error(ServiceOrders::Errors::PartsCatalogUnavailable, /invalid_response/)
  end

  it "escapes the part id" do
    stub_request(:get, "http://execution:3000/api/v1/parts/a%2Fb").to_return(status: 200, body: "{}")

    expect(catalog.fetch("a/b")).to eq({})
  end
end
