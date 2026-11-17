require "net/http"

module ServiceOrders
  module Gateways
    # Synchronous REST call to the Execution Service, which owns the parts
    # catalog and stock. Used when an order is opened to snapshot the part name
    # and price; the admin's bearer token is forwarded.
    class PartsCatalog
      def initialize(auth_token:, base_url: ENV.fetch("EXECUTION_SERVICE_URL", "http://localhost:3002"), timeout: 3)
        @auth_token = auth_token
        @base_url   = base_url.chomp("/")
        @timeout    = timeout
      end

      def fetch(part_id)
        response = get("/api/v1/parts/#{ERB::Util.url_encode(part_id.to_s)}")

        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        when Net::HTTPNotFound
          raise Errors::PartNotFound, "Part #{part_id} not found in the parts catalog"
        else
          unavailable!("http_#{response.code}")
        end
      rescue Errors::PartNotFound
        raise
      rescue JSON::ParserError
        unavailable!("invalid_response")
      rescue Errors::PartsCatalogUnavailable
        raise
      rescue StandardError => e
        unavailable!(e.class.name.demodulize.underscore)
      end

      private

      def get(path)
        uri = URI("#{@base_url}#{path}")
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: @timeout, read_timeout: @timeout) do |http|
          request = Net::HTTP::Get.new(uri)
          request["Authorization"] = "Bearer #{@auth_token}"
          request["Accept"]        = "application/json"
          http.request(request)
        end
      end

      def unavailable!(reason)
        Telemetry.integration_error(integration: "execution_service", reason: reason)
        raise Errors::PartsCatalogUnavailable, "Parts catalog unavailable (#{reason})"
      end
    end
  end
end
