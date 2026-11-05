
require "rails_helper"

RSpec.describe ReimbursementIdempotencyService do
  self.use_transactional_tests = false
  def with_idempotency_tenant
    subdomain = "idempotency#{SecureRandom.hex(4)}"

    Companies::Provision.call(
      name: "Idempotency Test Company",
      subdomain: subdomain
    ) do |company|
      employee = create(:user, company: company, role: :member)
      admin = create(:user, company: company, role: :admin)
      category = create(:category)

      expense = create(
        :expense,
        user: employee,
        category: category,
        status: "approved"
      )

      yield expense, admin, employee, category
    end
  ensure
    Apartment::Tenant.reset

    if subdomain && ActiveRecord::Base.connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end
  end

  def reimburse(expense, admin, key)
    described_class.call(
      expense: expense,
      actor: admin,
      idempotency_key: key
    )
  end

  describe ".call" do
    it "returns 400 when the idempotency key is missing" do
      with_idempotency_tenant do |expense, admin, _employee, _category|
        result = reimburse(expense, admin, nil)

        expect(result.value[:status]).to eq(:bad_request)
        expect(result.value[:body][:errors]).to include(
          "Idempotency-Key header is required"
        )
        expect(expense.reload.status).to eq("approved")
        expect(ReimbursementIdempotencyRecord.count).to eq(0)
      end
    end

    it "replays the original response for the same key and expense" do
      with_idempotency_tenant do |expense, admin, _employee, _category|
        first_result = reimburse(expense, admin, "reimburse-123")
        second_result = reimburse(expense, admin, "reimburse-123")

        expect(first_result.value[:status]).to eq(200)
        expect(second_result.value[:status]).to eq(first_result.value[:status])
        expect(second_result.value[:body]).to eq(first_result.value[:body])
        expect(second_result.value[:replayed]).to be(true)

        expect(expense.reload.status).to eq("reimbursed")
        expect(
          ReimbursementIdempotencyRecord.where(
            idempotency_key: "reimburse-123"
          ).count
        ).to eq(1)
      end
    end

    it "does not create another reimbursement record on replay" do
      with_idempotency_tenant do |expense, admin, _employee, _category|
        reimburse(expense, admin, "reimburse-456")

        expect do
          reimburse(expense, admin, "reimburse-456")
        end.not_to change(ReimbursementIdempotencyRecord, :count)

        expect(expense.reload.status).to eq("reimbursed")
      end
    end

    it "rejects a key already used for a different expense" do
      with_idempotency_tenant do |expense, admin, employee, category|
        reimburse(expense, admin, "shared-key")

        another_expense = create(
          :expense,
          user: employee,
          category: category,
          status: "approved"
        )

        expect do
          reimburse(another_expense, admin, "shared-key")
        end.to raise_error(
          Errors::IdempotencyConflict,
          "Idempotency-Key has already been used for another expense"
        )

        expect(Errors::IdempotencyConflict.new.status).to eq(:conflict)
        expect(another_expense.reload.status).to eq("approved")
        expect(ReimbursementIdempotencyRecord.count).to eq(1)
      end
    end
  end
end
