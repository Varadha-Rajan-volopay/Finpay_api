
require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  self.use_transactional_tests = false

  let(:company) do
    create(
      :company,
      subdomain: "login#{SecureRandom.hex(3)}"
    )
  end

  let(:email) { "member@example.com" }
  let(:password) { "password123" }

  before do
    connection = ActiveRecord::Base.connection

    connection.execute(
      "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
    )

    Companies::TenantMigration.run!(company.subdomain)

    Apartment::Tenant.switch(company.subdomain) do
      create(
        :user,
        company: company,
        email: email,
        password: password,
        password_confirmation: password,
        role: :member
      )
    end
  end

  after do
    Apartment::Tenant.reset

    if company&.persisted?
      connection = ActiveRecord::Base.connection

      if connection.schema_exists?(company.subdomain)
        Apartment::Tenant.drop(company.subdomain)
      end

      company.delete
    end
  end

  describe "POST /auth/login" do
    it "logs in and returns a JWT containing the company_id" do
      post "/auth/login", params: {
        company: {
          subdomain: company.subdomain
        },
        user: {
          email: email,
          password: password
        }
      }

      expect(response).to have_http_status(:ok)

      token = response.headers["Authorization"]&.split(" ")&.last
      expect(token).to be_present

      payload, = JWT.decode(
        token,
        Rails.application.secret_key_base,
        true,
        algorithm: "HS256"
      )

      expect(payload["company_id"].to_s).to eq(company.id.to_s)
      expect(response.parsed_body.dig("user", "email")).to eq(email)
    end

    it "rejects an expired JWT" do
      expired_payload = {
        "sub" => "999",
        "scp" => "user",
        "company_id" => company.id,
        "role" => "member",
        "jti" => SecureRandom.uuid,
        "iat" => 10.minutes.ago.to_i,
        "exp" => 1.minute.ago.to_i
      }

      expired_token = JWT.encode(
        expired_payload,
        Rails.application.secret_key_base,
        "HS256"
      )

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{expired_token}"
      }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects invalid credentials" do
      post "/auth/login", params: {
        company: {
          subdomain: company.subdomain
        },
        user: {
          email: email,
          password: "incorrect_password"
        }
      }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to have_key("error")
    end

    it "rejects an unknown company subdomain" do
      post "/auth/login", params: {
        company: {
          subdomain: "unknown#{SecureRandom.hex(3)}"
        },
        user: {
          email: email,
          password: password
        }
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /auth/logout" do
    it "revokes the JWT" do
      post "/auth/login", params: {
        company: {
          subdomain: company.subdomain
        },
        user: {
          email: email,
          password: password
        }
      }

      expect(response).to have_http_status(:ok)

      token = response.headers["Authorization"]&.split(" ")&.last
      expect(token).to be_present

      payload, = JWT.decode(
        token,
        Rails.application.secret_key_base,
        true,
        algorithm: "HS256"
      )

      Apartment::Tenant.switch(company.subdomain) do
        delete "/auth/logout", headers: {
          "Authorization" => "Bearer #{token}"
        }
      end

      expect(response).to have_http_status(:ok)

      expect(
        JwtDenylist.exists?(jti: payload["jti"])
      ).to be(true)

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{token}"
      }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects logout when the Authorization token is missing" do
      delete "/auth/logout"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq("Missing token")
    end

    it "rejects logout when the Authorization header is empty" do
      delete "/auth/logout", headers: {
        "Authorization" => ""
      }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq("Missing token")
    end
  end
  describe "GET /auth/login" do
    it "returns the login endpoint response" do
      get "/auth/login"

      expect(response).to have_http_status(:ok)
    end
  end
end
