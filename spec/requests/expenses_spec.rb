require "rails_helper"

RSpec.describe "Expenses", type: :request do
  self.use_transactional_tests = false

  let(:company_a) do
    create(:company, subdomain: "expense_a_#{SecureRandom.hex(3)}")
  end

  let(:company_b) do
    create(:company, subdomain: "expense_b_#{SecureRandom.hex(3)}")
  end

  let(:user_a) do
    Apartment::Tenant.switch(company_a.subdomain) do
      create(
        :user,
        company: company_a,
        role: :member,
        email: "member_a_#{SecureRandom.hex(3)}@example.com"
      )
    end
  end

  let(:admin_a) do
    Apartment::Tenant.switch(company_a.subdomain) do
      create(
        :user,
        company: company_a,
        role: :admin,
        email: "admin_a_#{SecureRandom.hex(3)}@example.com"
      )
    end
  end

  let(:user_b) do
    Apartment::Tenant.switch(company_b.subdomain) do
      create(
        :user,
        company: company_b,
        role: :member,
        email: "member_b_#{SecureRandom.hex(3)}@example.com"
      )
    end
  end

  before do
    host! "localhost"

    [ company_a, company_b ].each do |company|
      connection = ActiveRecord::Base.connection

      unless connection.schema_exists?(company.subdomain)
        connection.execute(
          "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
        )
      end

      Companies::TenantMigration.run!(company.subdomain)
    end

    user_a
    admin_a
    user_b
  end

  after do
    Apartment::Tenant.reset

    [ company_a, company_b ].each do |company|
      next unless company&.persisted?

      connection = ActiveRecord::Base.connection

      if connection.schema_exists?(company.subdomain)
        Apartment::Tenant.drop(company.subdomain)
      end

      company.delete
    end
  end

  # Generates a JWT for the supplied user.
  def access_token_for(user)
    token, = Warden::JWTAuth::UserEncoder.new.call(
      user,
      :user,
      nil
    )

    token
  end

  # Adds the JWT to the Authorization header.
  def auth_headers(user)
    {
      "Authorization" => "Bearer #{access_token_for(user)}"
    }
  end

  # Creates an expense inside the user's tenant schema.
  def create_expense(user:, title: "Team lunch", status: "pending")
    Apartment::Tenant.switch(user.company.subdomain) do
      category = create(:category)

      create(
        :expense,
        user: user,
        category: category,
        title: title,
        status: status
      )
    end
  end

  # Handles a response that is either a JSON object or a JSON string.
  def decoded_response_body
    body = JSON.parse(response.body)
    body.is_a?(String) ? JSON.parse(body) : body
  end

  # Extracts serialized expense records from the response.
  def expense_data_from_body(body)
    data = body["data"]
    data.is_a?(String) ? JSON.parse(data) : data
  end

  describe "GET /expenses" do
    it "returns only the current member's expenses" do
      own_expense = create_expense(user: user_a)
      create_expense(user: admin_a, title: "Admin expense")

      get "/expenses", headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok),
        "Expected 200, but got #{response.status}: #{response.body}"

      body = decoded_response_body
      data = expense_data_from_body(body)

      expect(data.map { |expense| expense["id"] }).to include(own_expense.id)
      expect(data.map { |expense| expense["title"] }).not_to include(
        "Admin expense"
      )
    end

    it "allows an admin to see expenses belonging to users in the tenant" do
      member_expense = create_expense(user: user_a)

      get "/expenses", headers: auth_headers(admin_a)

      expect(response).to have_http_status(:ok)

      body = decoded_response_body
      data = expense_data_from_body(body)

      expect(data.map { |expense| expense["id"] }).to include(member_expense.id)
    end

    it "does not return expenses belonging to another tenant" do
      expense_from_company_b = create_expense(user: user_b)

      get "/expenses", headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      body = decoded_response_body
      data = expense_data_from_body(body)

      expect(data.map { |expense| expense["id"] }).not_to include(
        expense_from_company_b.id
      )
    end

    it "returns 422 for an invalid status filter" do
      get "/expenses",
          params: { status: "not_a_status" },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(decoded_response_body).to have_key("error")
    end

    it "filters expenses by category_id" do
      matching_expense = create_expense(user: user_a)
      other_expense = create_expense(user: user_a)

      get "/expenses",
          params: { category_id: matching_expense.category_id },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      data = expense_data_from_body(decoded_response_body)
      returned_ids = data.map { |expense| expense["id"] }

      expect(returned_ids).to include(matching_expense.id)
      expect(returned_ids).not_to include(other_expense.id)
    end

    it "filters expenses by status" do
      pending_expense = create_expense(
        user: user_a,
        status: "pending"
      )

      approved_expense = create_expense(
        user: user_a,
        status: "approved"
      )

      get "/expenses",
          params: { status: "pending" },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      data = expense_data_from_body(decoded_response_body)
      returned_ids = data.map { |expense| expense["id"] }

      expect(returned_ids).to include(pending_expense.id)
      expect(returned_ids).not_to include(approved_expense.id)
    end

    it "filters expenses from the given incurred_on date" do
      matching_expense = create_expense(user: user_a)
      earlier_expense = create_expense(user: user_a)

      Apartment::Tenant.switch(company_a.subdomain) do
        matching_expense.update!(incurred_on: Date.new(2026, 10, 15))
        earlier_expense.update!(incurred_on: Date.new(2026, 10, 5))
      end

      get "/expenses",
          params: { from: "2026-10-15" },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      data = expense_data_from_body(decoded_response_body)
      returned_ids = data.map { |expense| expense["id"] }

      expect(returned_ids).to include(matching_expense.id)
      expect(returned_ids).not_to include(earlier_expense.id)
    end

    it "filters expenses up to the given incurred_on date" do
      matching_expense = create_expense(user: user_a)
      later_expense = create_expense(user: user_a)

      Apartment::Tenant.switch(company_a.subdomain) do
        matching_expense.update!(incurred_on: Date.new(2026, 10, 15))
        later_expense.update!(incurred_on: Date.new(2026, 10, 25))
      end

      get "/expenses",
          params: { to: "2026-10-15" },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      data = expense_data_from_body(decoded_response_body)
      returned_ids = data.map { |expense| expense["id"] }

      expect(returned_ids).to include(matching_expense.id)
      expect(returned_ids).not_to include(later_expense.id)
    end

    it "returns 422 for an invalid from date" do
      get "/expenses",
          params: { from: "not-a-date" },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 for an invalid to date" do
      get "/expenses",
          params: { to: "2026-02-30" },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when from is later than to" do
      get "/expenses",
          params: {
            from: "2026-10-20",
            to: "2026-10-10"
          },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 for an invalid category_id" do
      get "/expenses",
          params: { category_id: "invalid" },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 for an unknown filter" do
      get "/expenses",
          params: { unknown_filter: "value" },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "uses the default page size when per is not provided" do
      3.times do |index|
        create_expense(user: user_a, title: "Expense #{index}")
      end

      get "/expenses", headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      body = decoded_response_body
      data = expense_data_from_body(body)

      expect(data.size).to eq(3)
      expect(body["meta"]["page"]).to eq(1)
    end

    it "caps per at 100 expenses" do
      Apartment::Tenant.switch(company_a.subdomain) do
        category = create(:category)

        101.times do |index|
          create(
            :expense,
            user: user_a,
            category: category,
            title: "Expense #{index}",
            status: "pending"
          )
        end
      end

      get "/expenses",
          params: { per: 150 },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      body = decoded_response_body
      data = expense_data_from_body(body)

      expect(data.size).to eq(100)
      expect(body["meta"]["total_pages"]).to eq(2)
    end

    it "does not trigger an N+1 query while listing expenses" do
      3.times do |index|
        create_expense(
          user: user_a,
          title: "Expense #{index}"
        )
      end

      get "/expenses", headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)
    end

    it "supports keyset pagination without duplicate or missing expenses" do
      expenses = 5.times.map do |index|
        create_expense(user: user_a, title: "Expense #{index}")
      end

      get "/expenses",
          params: {
            pagination: "keyset",
            per: 2
          },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      first_body = decoded_response_body
      first_data = expense_data_from_body(first_body)

      expect(first_data.size).to eq(2)
      expect(first_body["meta"]["has_next"]).to be(true)

      first_cursor = first_body["meta"]["next_cursor"]
      expect(first_cursor).to be_present

      get "/expenses",
          params: {
            pagination: "keyset",
            per: 2,
            cursor: first_cursor
          },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      second_body = decoded_response_body
      second_data = expense_data_from_body(second_body)

      expect(second_data.size).to eq(2)
      expect(second_body["meta"]["has_next"]).to be(true)

      second_cursor = second_body["meta"]["next_cursor"]
      expect(second_cursor).to be_present

      get "/expenses",
          params: {
            pagination: "keyset",
            per: 2,
            cursor: second_cursor
          },
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)

      third_body = decoded_response_body
      third_data = expense_data_from_body(third_body)

      expect(third_data.size).to eq(1)
      expect(third_body["meta"]["has_next"]).to be(false)

      returned_ids = (
        first_data + second_data + third_data
      ).map { |expense| expense["id"] }

      expected_ids = expenses
        .sort_by { |expense| [ expense.created_at, expense.id ] }
        .reverse
        .map(&:id)

      expect(returned_ids).to eq(expected_ids)
      expect(returned_ids.uniq.size).to eq(5)
    end
  end

  describe "GET /expenses/:id" do
    it "allows a member to view their own expense" do
      expense = create_expense(user: user_a)

      get "/expenses/#{expense.id}", headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)
      expect(decoded_response_body["id"]).to eq(expense.id)
    end

    it "does not allow a member to view another member's expense" do
      expense = create_expense(user: admin_a)

      get "/expenses/#{expense.id}", headers: auth_headers(user_a)

      expect(response).to have_http_status(:not_found)
    end

    it "does not expose an expense from another tenant" do
      expense = create_expense(user: user_b)

      get "/expenses/#{expense.id}", headers: auth_headers(user_a)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /expenses" do
    it "creates a pending expense for the authenticated user" do
      category = Apartment::Tenant.switch(company_a.subdomain) do
        create(:category)
      end

      post "/expenses",
           params: {
             expense: {
               title: "Office supplies",
               category_id: category.id,
               amount_cents: 2500,
               currency: "INR",
               incurred_on: Date.current,
               status: "approved",
               user_id: admin_a.id
             }
           },
           headers: auth_headers(user_a)

      expect(response).to have_http_status(:created)

      body = decoded_response_body

      expect(body["title"]).to eq("Office supplies")
      expect(body["user_id"]).to eq(user_a.id)
      expect(body["status"]).to eq("pending")
    end

    it "returns validation errors for invalid expense data" do
      category = Apartment::Tenant.switch(company_a.subdomain) do
        create(:category)
      end

      post "/expenses",
           params: {
             expense: {
               title: "",
               category_id: category.id,
               amount_cents: 2500,
               currency: "INR",
               incurred_on: Date.current
             }
           },
           headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(decoded_response_body).to have_key("errors")
    end
  end

  describe "PATCH /expenses/:id" do
    it "allows the owner to update a pending expense" do
      expense = create_expense(user: user_a)

      patch "/expenses/#{expense.id}",
            params: {
              expense: {
                title: "Updated lunch",
                amount_cents: 1500
              }
            },
            headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)
      expect(decoded_response_body["title"]).to eq("Updated lunch")
    end

    it "does not allow a member to update another member's expense" do
      expense = create_expense(user: admin_a)

      patch "/expenses/#{expense.id}",
            params: {
              expense: {
                title: "Unauthorized update"
              }
            },
            headers: auth_headers(user_a)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow the owner to update a non-pending expense" do
      expense = create_expense(user: user_a, status: "approved")

      patch "/expenses/#{expense.id}",
            params: {
              expense: {
                title: "Changed title"
              }
            },
            headers: auth_headers(user_a)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /expenses/:id" do
    it "allows the owner to delete a pending expense" do
      expense = create_expense(user: user_a)

      delete "/expenses/#{expense.id}", headers: auth_headers(user_a)

      expect(response).to have_http_status(:no_content)

      Apartment::Tenant.switch(company_a.subdomain) do
        expect(Expense.exists?(expense.id)).to be(false)
      end
    end

    it "does not allow a member to delete another member's expense" do
      expense = create_expense(user: admin_a)

      delete "/expenses/#{expense.id}", headers: auth_headers(user_a)

      expect(response).to have_http_status(:not_found)
    end

    it "does not allow the owner to delete a non-pending expense" do
      expense = create_expense(user: user_a, status: "approved")

      delete "/expenses/#{expense.id}", headers: auth_headers(user_a)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
