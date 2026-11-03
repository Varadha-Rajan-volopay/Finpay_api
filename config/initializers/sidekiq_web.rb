# frozen_string_literal: true

require "sidekiq/web"

Sidekiq::Web.use Rack::Auth::Basic do |provided_username, provided_password|
  expected_username =
    ENV["SIDEKIQ_WEB_USERNAME"].presence ||
    Rails.application.credentials.dig(:sidekiq_web, :username)

  expected_password =
    ENV["SIDEKIQ_WEB_PASSWORD"].presence ||
    Rails.application.credentials.dig(:sidekiq_web, :password)

  expected_username.present? &&
    expected_password.present? &&
    ActiveSupport::SecurityUtils.secure_compare(
      provided_username,
      expected_username
    ) &&
    ActiveSupport::SecurityUtils.secure_compare(
      provided_password,
      expected_password
    )
end
