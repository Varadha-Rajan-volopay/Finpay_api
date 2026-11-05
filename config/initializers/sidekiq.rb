# frozen_string_literal: true

require "sidekiq-cron"

redis_url = if Rails.env.production?
              ENV.fetch("REDIS_URL")
else
              ENV.fetch("REDIS_URL", "redis://localhost:6380/0")
end

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
