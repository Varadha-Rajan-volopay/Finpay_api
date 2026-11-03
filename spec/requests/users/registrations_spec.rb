require "rails_helper"

RSpec.describe "Users::Registrations", type: :request do
  describe "POST /auth/register" do
    let(:registration_params) do
      {
        company: {
          name: "Finpay Test Company",
          subdomain: "finpaytest#{SecureRandom.hex(3)}"
        },
        user: {
          email: "admin@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    it "registers a company and its admin user" do
      post "/auth/register", params: registration_params

      expect(response).to have_http_status(:created)

      body = response.parsed_body

      expect(body["message"]).to eq(
        "Company and admin user registered successfully"
      )

      expect(body.dig("company", "subdomain")).to eq(
        registration_params.dig(:company, :subdomain)
      )

      expect(body.dig("user", "email")).to eq("admin@example.com")
      expect(body.dig("user", "role")).to eq("admin")

      company = Company.find_by(
        subdomain: registration_params.dig(:company, :subdomain)
      )

      expect(company).to be_present

      Apartment::Tenant.switch(company.subdomain) do
        user = User.find_by(email: "admin@example.com")

        expect(user).to be_present
        expect(user.company_id).to eq(company.id)
        expect(user).to be_admin
      end
    ensure
      Apartment::Tenant.reset

      if company&.persisted?
        tenant_name = company.subdomain

        if ActiveRecord::Base.connection.schema_exists?(tenant_name)
          Apartment::Tenant.drop(tenant_name)
        end

        company.delete
      end
    end

    it "returns an error when the registration data is invalid" do
      invalid_params = registration_params.deep_dup
      invalid_params[:user][:password_confirmation] = "different_password"

      post "/auth/register", params: invalid_params

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to have_key("errors")
    end
  end
end
