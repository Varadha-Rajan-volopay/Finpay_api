
require "rails_helper"

RSpec.describe "Tenant isolation", type: :request do
  include_context "tenant schemas"

  let(:company_a) do
    create_test_tenant(name: "Tenant A")
  end

  let(:company_b) do
    create_test_tenant(name: "Tenant B")
  end

  let(:user_a) do
    with_test_tenant(company_a) do
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
    company_a
    company_b
    user_a
  end

  describe "GET /auth/me" do
    it "does not let X-Company-Id override the token tenant" do
      token = auth_token_for(user_a)

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{token}",
        "X-Company-Id" => company_b.id.to_s
      }

      expect(response).to have_http_status(:ok)
      expect(
        response.parsed_body.dig("user", "company_id").to_s
      ).to eq(company_a.id.to_s)
    end

    it "rejects a token without a company_id claim" do
      payload = auth_token_payload(auth_token_for(user_a))
      payload.delete("company_id")

      invalid_token = JWT.encode(
        payload,
        Rails.application.secret_key_base,
        "HS256"
      )

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{invalid_token}"
      }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code"))
        .to eq("tenant_not_found")
    end

    it "rejects a token referencing a company that does not exist" do
      payload = auth_token_payload(auth_token_for(user_a))
      payload["company_id"] = -1

      invalid_token = JWT.encode(
        payload,
        Rails.application.secret_key_base,
        "HS256"
      )

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{invalid_token}"
      }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code"))
        .to eq("tenant_not_found")
    end

    it "rejects a JWT with an invalid signature" do
      payload = {
        "sub" => user_a.id,
        "scp" => "user",
        "company_id" => company_a.id,
        "role" => "member",
        "jti" => SecureRandom.uuid,
        "iat" => Time.current.to_i,
        "exp" => 10.minutes.from_now.to_i
      }

      invalid_token = JWT.encode(
        payload,
        "wrong-secret",
        "HS256"
      )

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{invalid_token}"
      }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a company whose tenant schema does not exist" do
      company_without_schema = create(
        :company,
        subdomain: "missing_schema_#{SecureRandom.hex(3)}"
      )

      payload = auth_token_payload(auth_token_for(user_a))
      payload["company_id"] = company_without_schema.id

      invalid_token = JWT.encode(
        payload,
        Rails.application.secret_key_base,
        "HS256"
      )

      get "/auth/me", headers: {
        "Authorization" => "Bearer #{invalid_token}"
      }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code"))
        .to eq("tenant_not_found")
    ensure
      Apartment::Tenant.reset
      company_without_schema&.delete
    end

    it "rejects a token whose company claim does not match the user" do
      payload = auth_token_payload(auth_token_for(user_a))
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

  describe "expense data isolation" do
    let!(:expense_a) do
      with_test_tenant(company_a) do
        category = create(:category, name: "Tenant A Category")

        create(
          :expense,
          user: user_a,
          category: category,
          title: "Tenant A confidential expense"
        )
      end
    end

    let!(:user_b) do
      with_test_tenant(company_b) do
        create(
          :user,
          company: company_b,
          email: "userb#{SecureRandom.hex(3)}@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: :member
        )
      end
    end

    it "keeps expenses isolated between tenant schemas" do
      with_test_tenant(company_a) do
        expect(
          Expense.find_by(title: "Tenant A confidential expense")
        ).to be_present
      end

      with_test_tenant(company_b) do
        expect(
          Expense.find_by(title: "Tenant A confidential expense")
        ).to be_nil

        category = create(:category, name: "Tenant B Category")

        create(
          :expense,
          user: user_b,
          category: category,
          title: "Tenant B confidential expense"
        )
      end

      with_test_tenant(company_a) do
        expect(
          Expense.find_by(title: "Tenant B confidential expense")
        ).to be_nil
      end
    end
  end

  describe "all tenant-owned resource isolation" do
    let!(:user_b) do
      with_test_tenant(company_b) do
        create(
          :user,
          company: company_b,
          email: "userb#{SecureRandom.hex(3)}@example.com"
        )
      end
    end

    it "isolates users, categories, receipts, activity logs, reminders and idempotency records" do
      allow(AuditLogWorker).to receive(:perform_async)
      allow(ReceiptProcessorWorker).to receive(:perform_async)

      with_test_tenant(company_a) do
        category = create(
          :category,
          name: "Tenant A isolated category"
        )

        expense = create(
          :expense,
          user: user_a,
          category: category,
          title: "Tenant A isolated expense"
        )

        create(
          :receipt,
          expense: expense,
          file_name: "tenant_a_private_receipt.pdf",
          storage_key: "tenant_a/private_receipt.pdf"
        )

        ActivityLog.create!(
          expense: expense,
          actor: user_a,
          action: "tenant_a_private_action",
          from_state: "new",
          to_state: "pending"
        )

        OverdueReminder.create!(
          expense: expense,
          reminder_date: Date.new(2001, 1, 1)
        )

        ReimbursementIdempotencyRecord.create!(
          expense: expense,
          actor: user_a,
          idempotency_key: "tenant-a-private-key",
          response_body: { message: "private response" },
          response_status: 200
        )
      end

      with_test_tenant(company_b) do
        expect(User.find_by(email: user_a.email)).to be_nil

        expect(
          Category.find_by(name: "Tenant A isolated category")
        ).to be_nil

        expect(
          Expense.find_by(title: "Tenant A isolated expense")
        ).to be_nil

        expect(
          Receipt.find_by(storage_key: "tenant_a/private_receipt.pdf")
        ).to be_nil

        expect(
          ActivityLog.find_by(action: "tenant_a_private_action")
        ).to be_nil

        expect(
          OverdueReminder.find_by(reminder_date: Date.new(2001, 1, 1))
        ).to be_nil

        expect(
          ReimbursementIdempotencyRecord.find_by(
            idempotency_key: "tenant-a-private-key"
          )
        ).to be_nil
      end
    end
  end
end
