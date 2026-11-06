# frozen_string_literal: true

require "rack/attack"
require "digest"

redis_url = if Rails.env.production?
              ENV.fetch("REDIS_URL")
            else
              ENV.fetch("REDIS_URL", "redis://localhost:6380/0")
            end

Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: redis_url,
  namespace: "rack-attack"
)

Rack::Attack.throttle("login/ip", limit: 5, period: 1.minute) do |request|
  if request.post? && request.path == "/api/v1/auth/login"
    request.ip
  end
end

Rack::Attack.throttle("login/email", limit: 5, period: 1.minute) do |request|
  if request.post? && request.path == "/api/v1/auth/login"
    email = request.params.dig("user", "email")
    email.to_s.strip.downcase.presence
  end
end

Rack::Attack.throttle("api/token", limit: 300, period: 1.minute) do |request|
  next unless request.path.start_with?("/api/v1/")
  next if request.path == "/up"

  token = request.get_header("HTTP_AUTHORIZATION").to_s
  match = token.match(/\ABearer\s+(.+)\z/i)

  Digest::SHA256.hexdigest(match[1]) if match
end

Rack::Attack.throttled_responder = lambda do |request|
  retry_after = (request.env["rack.attack.match_data"][:period] -
    (Time.now.to_i % request.env["rack.attack.match_data"][:period])).to_s

  body = {
    error: {
      code: "rate_limit_exceeded",
      message: "Too many requests",
      details: []
    }
  }.to_json

  [
    429,
    {
      "Content-Type" => "application/json",
      "Retry-After" => retry_after
    },
    [body]
  ]
end
