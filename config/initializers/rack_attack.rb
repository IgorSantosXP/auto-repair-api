class Rack::Attack
  if Rails.env.test?
    Rack::Attack.enabled = false
  else
    throttle("login/ip", limit: 5, period: 5.minutes) do |req|
      req.ip if req.path == "/api/v1/auth/login" && req.post?
    end

    throttle("customer_orders/ip", limit: 10, period: 1.minute) do |req|
      req.ip if req.path.match?(%r{/api/v1/customer/service_orders/.+/(approve|reject)}) && req.post?
    end

    self.throttled_responder = lambda do |request|
      retry_after = (request.env["rack.attack.match_data"] || {})[:period]
      [
        429,
        {
          "Content-Type" => "application/json",
          "Retry-After"  => retry_after.to_s
        },
        [{ error: { code: "too_many_requests", message: "Too many requests. Please try again later." } }.to_json]
      ]
    end
  end
end
