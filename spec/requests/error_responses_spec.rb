
require "rails_helper"

RSpec.describe "API error responses", type: :request do
  self.use_transactional_tests = false

  let(:company) do
    create(:company, subdomain: "error_spec_#{SecureRandom.hex(3)}")
  end

  let(:member) do
    Apartment::Tenant.switch(company.subdomain) do
      create(:user, company: company, role: :member)
    end
  end

  let(:admin) do
    Apartment::Tenant.switch(company.subdomain) do
      create(:user, company: company, role: :admin)
    end
  end

  before do
    host! "localhost"

    connection = ActiveRecord::Base.connection
    connection.execute(
      "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
    )

    Companies::TenantMigration.run!(company.subdomain)

    member
    admin
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

  def access_token_for(user)
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    token
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{access_token_for(user)}" }
  end

  def expect_standard_error(code)
    body = response.parsed_body

    expect(body).to have_key("error")
    expect(body["error"]).to include(
      "code" => code,
      "message" => be_a(String),
      "details" => be_a(Array)
    )
  end

  it "returns a consistent 401 response for unauthenticated requests" do
    get "/expenses"

    expect(response).to have_http_status(:unauthorized)
    expect_standard_error("tenant_not_found")
  end

  it "returns a consistent 403 response for forbidden actions" do
    expense = Apartment::Tenant.switch(company.subdomain) do
      category = create(:category)
      create(:expense, user: member, category: category)
    end

    post "/expenses/#{expense.id}/approve",
         headers: auth_headers(member)

    expect(response).to have_http_status(:forbidden)
    expect_standard_error("forbidden")
  end

  it "returns a consistent 404 response for missing expenses" do
    get "/expenses/999999999",
        headers: auth_headers(member)

    expect(response).to have_http_status(:not_found)
    expect_standard_error("not_found")
  end

  it "returns a consistent 422 response for invalid filters" do
    get "/expenses",
        params: { status: "invalid_status" },
        headers: auth_headers(member)

    expect(response).to have_http_status(:unprocessable_entity)
    expect_standard_error("invalid_filter")
  end

  it "does not expose SQL statements or stack traces in error responses" do
    get "/expenses",
        params: { status: "invalid_status" },
        headers: auth_headers(member)

    expect(response).to have_http_status(:unprocessable_entity)

    expect(response.body).not_to match(
      /SELECT\s|INSERT\s|UPDATE\s|DELETE\s|ActiveRecord::|PG::|backtrace|app\/controllers/i
    )
  end
  it "returns a consistent 400 response when the expense parameter is missing" do
    post "/expenses",
        params: {},
        headers: auth_headers(member)

    expect(response).to have_http_status(:bad_request)
    expect_standard_error("bad_request")
  end

  it "returns a consistent 401 response for a missing tenant" do
    allow(Company).to receive(:find_by).and_return(nil)

    token = access_token_for(member)

    payload, = JWT.decode(
      token,
      Rails.application.secret_key_base,
      true,
      algorithm: "HS256"
    )

    payload.delete("company_id")

    invalid_token = JWT.encode(
      payload,
      Rails.application.secret_key_base,
      "HS256"
    )

    get "/expenses",
        headers: { "Authorization" => "Bearer #{invalid_token}" }

    expect(response).to have_http_status(:unauthorized)
    expect_standard_error("tenant_not_found")
  end

  it "returns a consistent 409 response for an idempotency conflict" do
    error = Errors::IdempotencyConflict.new(
      "Idempotency key conflict"
    )

    allow(ExpenseFilter).to receive(:new).and_raise(error)

    get "/expenses",
        headers: auth_headers(member)

    expect(response).to have_http_status(:conflict)
    expect_standard_error("idempotency_conflict")
  end

  it "returns a consistent 409 response for duplicate database records" do
    allow(ExpenseFilter).to receive(:new)
      .and_raise(ActiveRecord::RecordNotUnique, "duplicate record")

    get "/expenses", headers: auth_headers(member)

    expect(response).to have_http_status(:conflict)
    expect_standard_error("conflict")
  end

  it "returns a consistent 409 response for invalid foreign keys" do
    allow(ExpenseFilter).to receive(:new)
      .and_raise(ActiveRecord::InvalidForeignKey, "invalid foreign key")

    get "/expenses", headers: auth_headers(member)

    expect(response).to have_http_status(:conflict)
    expect_standard_error("conflict")
  end

  it "returns a sanitized 500 response for unexpected errors" do
    allow(ExpenseFilter).to receive(:new)
      .and_raise(StandardError, "internal database details")

    expect(Rails.logger).to receive(:error)
      .with(/Unhandled StandardError: internal database details/)

    get "/expenses", headers: auth_headers(member)

    expect(response).to have_http_status(:internal_server_error)
    expect_standard_error("internal_server_error")
    expect(response.body).not_to include("internal database details")
  end

  it "returns a consistent 422 response for invalid AASM transitions" do
    expense = Apartment::Tenant.switch(company.subdomain) do
      category = create(:category)
      create(:expense, user: member, category: category, status: "pending")
    end

    allow(ExpenseWorkflowService).to receive(:call)
      .and_raise(
        AASM::InvalidTransition.new(
          expense,
          :archive,
          :default
        )
      )

    post "/expenses/#{expense.id}/archive",
        headers: auth_headers(admin)

    expect(response).to have_http_status(:unprocessable_entity)
    expect_standard_error("invalid_transition")
  end
end
