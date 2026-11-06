# frozen_string_literal: true

allowed_origins = ENV.fetch(
  "CORS_ALLOWED_ORIGINS",
  (Rails.env.development? || Rails.env.test?) ?
    "http://localhost:3000,http://localhost:5173" : ""
).split(",").map(&:strip).reject(&:blank?)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "/api/*",
      headers: %w[Authorization Content-Type Idempotency-Key],
      methods: %i[get post put patch delete options head],
      max_age: 600
  end
end
