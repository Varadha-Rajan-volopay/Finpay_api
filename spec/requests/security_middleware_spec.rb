require "rails_helper"

RSpec.describe "Security middleware", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.cache.store.clear
  end

  describe "login rate limiting" do
    def login(email:, ip: "192.0.2.10")
      post "/api/v1/auth/login",
           params: {
             company: { subdomain: "unknown-company" },
             user: { email: email, password: "wrong-password" }
           },
           headers: { "REMOTE_ADDR" => ip }
    end

    it "blocks the sixth login attempt from the same IP" do
      5.times do |index|
        login(email: "member#{index}@example.com")
        expect(response).not_to have_http_status(:too_many_requests)
      end

      login(email: "another@example.com")

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
      expect(response.parsed_body.dig("error", "code"))
        .to eq("rate_limit_exceeded")
    end

    it "normalizes email addresses when applying the email limit" do
      5.times do |index|
        login(
          email: index.even? ? "Member@example.com" : "member@EXAMPLE.COM",
          ip: "192.0.2.#{index + 20}"
        )
        expect(response).not_to have_http_status(:too_many_requests)
      end

      login(email: " MEMBER@EXAMPLE.COM ", ip: "192.0.2.30")

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
    end

    it "allows login attempts again after the throttle period" do
      5.times { |index| login(email: "member#{index}@example.com") }

      login(email: "blocked@example.com")
      expect(response).to have_http_status(:too_many_requests)

      travel 61.seconds

      login(email: "after-reset@example.com")
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  describe "authenticated API rate limiting" do
    it "blocks requests after 300 requests using the same bearer token" do
      headers = { "Authorization" => "Bearer test-rate-limit-token" }

      300.times do
        get "/api/v1/auth/me", headers: headers
        expect(response).not_to have_http_status(:too_many_requests)
      end

      get "/api/v1/auth/me", headers: headers

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
      expect(response.parsed_body.dig("error", "code"))
        .to eq("rate_limit_exceeded")
    end

    it "does not throttle the health endpoint" do
      headers = { "Authorization" => "Bearer health-check-token" }

      6.times do
        get "/up", headers: headers
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "CORS" do
    it "allows configured development frontend origins" do
      options "/api/v1/expenses",
              headers: {
                "Origin" => "http://localhost:5173",
                "Access-Control-Request-Method" => "GET"
              }

      expect(response.headers["access-control-allow-origin"])
        .to eq("http://localhost:5173")
    end

    it "does not allow an unconfigured origin" do
      options "/api/v1/expenses",
              headers: {
                "Origin" => "https://untrusted.example",
                "Access-Control-Request-Method" => "GET"
              }

      expect(response.headers["access-control-allow-origin"]).to be_nil
    end
  end
    describe "secure response headers" do
    it "sets X-Content-Type-Options to nosniff" do
      get "/up"

      expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    end

    it "prevents clickjacking" do
      get "/up"

      expect(response.headers["X-Frame-Options"]).to eq("DENY")
    end

    it "sets a restrictive referrer policy" do
      get "/up"

      expect(response.headers["Referrer-Policy"])
        .to eq("strict-origin-when-cross-origin")
    end

    it "does not expose the application framework version" do
      get "/up"

      expect(response.headers["X-Powered-By"]).to be_nil
      expect(response.headers["Server"]).not_to match(/\d+\.\d+/)
    end
  end
end
