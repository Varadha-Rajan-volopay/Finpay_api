# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sidekiq Web dashboard", type: :request do
  let(:username) { "sidekiq_admin" }
  let(:password) { "test_sidekiq_password" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SIDEKIQ_WEB_USERNAME").and_return(username)
    allow(ENV).to receive(:[]).with("SIDEKIQ_WEB_PASSWORD").and_return(password)
  end

  it "rejects requests without credentials" do
    get "/sidekiq"

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects incorrect credentials" do
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials(
      username,
      "incorrect_password"
    )

    get "/sidekiq", headers: { "HTTP_AUTHORIZATION" => credentials }

    expect(response).to have_http_status(:unauthorized)
  end

  it "allows requests with valid credentials" do
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials(
      username,
      password
    )

    get "/sidekiq", headers: { "HTTP_AUTHORIZATION" => credentials }

    expect(response).to have_http_status(:ok)
  end
end
