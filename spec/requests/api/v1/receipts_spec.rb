require "rails_helper"
require "tempfile"

RSpec.describe "Receipts", type: :request do
  self.use_transactional_tests = false

  let(:company_a) do
    create(:company, subdomain: "receipt_a_#{SecureRandom.hex(3)}")
  end

  let(:company_b) do
    create(:company, subdomain: "receipt_b_#{SecureRandom.hex(3)}")
  end

  let(:user_a) do
    Apartment::Tenant.switch(company_a.subdomain) do
      create(:user, company: company_a, role: :member)
    end
  end

  let(:user_b) do
    Apartment::Tenant.switch(company_b.subdomain) do
      create(:user, company: company_b, role: :member)
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
    user_b

    allow(ReceiptProcessorWorker).to receive(:perform_async)
  end

  after do
    Apartment::Tenant.reset

    Array(@tempfiles).each do |tempfile|
      tempfile.close!
    end

    Array(@storage_keys).each do |storage_key|
      FileUtils.rm_f(
        Rails.root.join("storage", "tenants", storage_key)
      )
    end

    [ company_a, company_b ].each do |company|
      next unless company&.persisted?

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

  def create_expense(user:)
    Apartment::Tenant.switch(user.company.subdomain) do
      category = create(:category)
      create(:expense, user: user, category: category)
    end
  end


  def build_uploaded_file(
    filename: "receipt.pdf",
    content_type: "application/pdf",
    content: "%PDF-1.4 fake receipt content"
  )
    tempfile = Tempfile.new([ "receipt", File.extname(filename) ])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    @tempfiles ||= []
    @tempfiles << tempfile

    Rack::Test::UploadedFile.new(
      tempfile.path,
      content_type,
      true,
      original_filename: filename
    )
  end


  def decoded_response_body
    body = JSON.parse(response.body)
    body.is_a?(String) ? JSON.parse(body) : body
  end

  def receipt_data_from_body
    data = decoded_response_body["data"]
    data.is_a?(String) ? JSON.parse(data) : data
  end

  describe "POST /api/v1/expenses/:expense_id/receipts" do
    it "uploads a valid PDF and enqueues OCR processing" do
      expense = create_expense(user: user_a)
      file = build_uploaded_file

      expect(ReceiptProcessorWorker).to receive(:perform_async)
        .with(company_a.id, anything)
        .once

      post "/api/v1/expenses/#{expense.id}/receipts",
           params: { file: file },
           headers: auth_headers(user_a)

      expect(response).to have_http_status(:created),
          "Response status: #{response.status}, body: #{response.body}"

      receipt = receipt_data_from_body

      expect(receipt["file_name"]).to eq("receipt.pdf")
      expect(receipt["content_type"]).to eq("application/pdf")
      expect(receipt["ocr_status"]).to eq("pending")
      expect(receipt["id"]).to be_present

      @storage_keys ||= []
      @storage_keys << Apartment::Tenant.switch(company_a.subdomain) do
        Receipt.find(receipt["id"]).storage_key
      end
    end

    it "returns 422 for an unsupported file type" do
      expense = create_expense(user: user_a)
      file = build_uploaded_file(
        filename: "receipt.txt",
        content_type: "text/plain",
        content: "Not a supported receipt"
      )

      post "/api/v1/expenses/#{expense.id}/receipts",
           params: { file: file },
           headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(decoded_response_body.dig("error", "code")).to eq("invalid_receipt")
    end

    it "returns 422 for an empty file" do
      expense = create_expense(user: user_a)
      file = build_uploaded_file(content: "")

      post "/api/v1/expenses/#{expense.id}/receipts",
           params: { file: file },
           headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(decoded_response_body).to have_key("error")
    end

    it "returns 422 when the file exceeds 10 MB" do
      expense = create_expense(user: user_a)
      file = build_uploaded_file(content: "a" * (10.megabytes + 1))

      post "/api/v1/expenses/#{expense.id}/receipts",
           params: { file: file },
           headers: auth_headers(user_a)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(decoded_response_body).to have_key("error")
    end

    it "does not allow a member to upload to another member's expense" do
      expense = create_expense(user: user_b)
      file = build_uploaded_file

      post "/api/v1/expenses/#{expense.id}/receipts",
           params: { file: file },
           headers: auth_headers(user_a)

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      expense = create_expense(user: user_a)
      file = build_uploaded_file

      post "/api/v1/expenses/#{expense.id}/receipts",
           params: { file: file }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/expenses/:expense_id/receipts/:id" do
    it "returns a receipt belonging to the authenticated user's expense" do
      expense = create_expense(user: user_a)

      receipt = Apartment::Tenant.switch(company_a.subdomain) do
        create(:receipt, expense: expense)
      end

      get "/api/v1/expenses/#{expense.id}/receipts/#{receipt.id}",
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:ok)
      expect(receipt_data_from_body["id"]).to eq(receipt.id)
      expect(receipt_data_from_body["ocr_status"]).to eq("pending")
    end

    it "does not expose another member's receipt" do
      expense = create_expense(user: user_b)

      receipt = Apartment::Tenant.switch(company_b.subdomain) do
        create(:receipt, expense: expense)
      end

      get "/api/v1/expenses/#{expense.id}/receipts/#{receipt.id}",
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:not_found)
    end

    it "does not expose a receipt belonging to another expense" do
      expense = create_expense(user: user_a)
      other_expense = create_expense(user: user_a)

      receipt = Apartment::Tenant.switch(company_a.subdomain) do
        create(:receipt, expense: other_expense)
      end

      get "/api/v1/expenses/#{expense.id}/receipts/#{receipt.id}",
          headers: auth_headers(user_a)

      expect(response).to have_http_status(:not_found)
    end
  end
end
