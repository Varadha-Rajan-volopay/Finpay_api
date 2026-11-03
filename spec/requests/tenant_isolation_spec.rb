
require "rails_helper"

RSpec.describe "Tenant isolation", type: :request do
  let(:company_a) do
    create(:company, subdomain: "tenant_a_#{SecureRandom.hex(3)}")
  end

  let(:company_b) do
    create(:company, subdomain: "tenant_b_#{SecureRandom.hex(3)}")
  end

  let(:user_a) do
    Apartment::Tenant.switch(company_a.subdomain) do
      create(
        :user,
        company: company_a,
        email: "usera#{SecureRandom.hex(3)}@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: :member
      )
    end
  end

  before do
    [ company_a, company_b ].each do |company|
      connection = ActiveRecord::Base.connection

      connection.execute(
        "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
      )

      Companies::TenantMigration.run!(company.subdomain)
    end

    user_a
  end

  after do
    Apartment::Tenant.reset

    [ company_a, company_b ].each do |company|
      next unless company&.persisted?

      if ActiveRecord::Base.connection.schema_exists?(company.subdomain)
        Apartment::Tenant.drop(company.subdomain)
      end

      company.delete
    end
  end

  def access_token_for(user)
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    token
  end

  describe "GET /auth/me" do
    it "does not let X-Company-Id override the token tenant" do
      token = access_token_for(user_a)

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{token}",
        "X-Company-Id" => company_b.id.to_s
      }

      puts "STATUS: #{response.status}"
      puts "BODY: #{response.body}"

      expect(response).to have_http_status(:ok)
      expect(
        response.parsed_body.dig("user", "company_id").to_s
        ).to eq(company_a.id.to_s)
    end

    it "rejects a token whose company claim does not match the user" do
      token = access_token_for(user_a)

      payload, = JWT.decode(
        token,
        Rails.application.secret_key_base,
        true,
        algorithm: "HS256"
      )

      payload["company_id"] = company_b.id

      mismatched_token = JWT.encode(
        payload,
        Rails.application.secret_key_base,
        "HS256"
      )

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{mismatched_token}"
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
