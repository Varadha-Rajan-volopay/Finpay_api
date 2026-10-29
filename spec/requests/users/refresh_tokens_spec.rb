
require "rails_helper"

RSpec.describe "Users::RefreshTokens", type: :request do
  let(:company) do
    create(:company, subdomain: "refresh#{SecureRandom.hex(3)}")
  end

  let(:user) do
    Apartment::Tenant.switch(company.subdomain) do
      create(
        :user,
        company: company,
        email: "refresh#{SecureRandom.hex(3)}@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: :member
      )
    end
  end

  before do
    connection = ActiveRecord::Base.connection

    connection.execute(
      "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
    )

    Companies::TenantMigration.run!(company.subdomain)
    user
  end

  after do
    Apartment::Tenant.reset

    if company&.persisted?
      if ActiveRecord::Base.connection.schema_exists?(company.subdomain)
        Apartment::Tenant.drop(company.subdomain)
      end

      company.delete
    end
  end

  def issue_refresh_token(expires_at: 30.days.from_now, revoked_at: nil)
    raw_token = SecureRandom.urlsafe_base64(64)

    record = RefreshToken.create!(
      company_id: company.id,
      user_id: user.id,
      token_digest: RefreshToken.digest(raw_token),
      expires_at: expires_at,
      revoked_at: revoked_at
    )

    [ record, raw_token ]
  end

  describe "POST /auth/refresh" do
    it "rotates a valid refresh token" do
      old_record, raw_token = issue_refresh_token

      post "/auth/refresh", params: {
        refresh_token: raw_token
      }

      expect(response).to have_http_status(:ok)

      body = response.parsed_body

      expect(body["access_token"]).to be_present
      expect(body["refresh_token"]).to be_present
      expect(body["refresh_token"]).not_to eq(raw_token)

      expect(old_record.reload.revoked_at).to be_present

      new_digest = RefreshToken.digest(body["refresh_token"])
      new_record = RefreshToken.find_by(token_digest: new_digest)

      expect(new_record).to be_present
      expect(new_record.active?).to be(true)
    end

    it "rejects a missing refresh token" do
      post "/auth/refresh", params: {}

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to have_key("error")
    end

    it "rejects an invalid refresh token" do
      post "/auth/refresh", params: {
        refresh_token: "invalid-refresh-token"
      }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to have_key("error")
    end

    it "rejects an expired refresh token" do
      _record, raw_token = issue_refresh_token(
        expires_at: 1.day.ago
      )

      post "/auth/refresh", params: {
        refresh_token: raw_token
      }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a revoked refresh token" do
      _record, raw_token = issue_refresh_token(
        revoked_at: Time.current
      )

      post "/auth/refresh", params: {
        refresh_token: raw_token
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
