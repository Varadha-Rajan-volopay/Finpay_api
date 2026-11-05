
require "rails_helper"

RSpec.describe ExpenseWorkflowIdempotencyService do
  self.use_transactional_tests = false

  def with_idempotency_tenant
    subdomain = "workflow#{SecureRandom.hex(4)}"

    Companies::Provision.call(
      name: "Workflow Idempotency Test Company",
      subdomain: subdomain
    ) do |company|
      employee = create(:user, company: company, role: :member)
      admin = create(:user, company: company, role: :admin)
      category = create(:category)

      expense = create(
        :expense,
        user: employee,
        category: category,
        status: "pending"
      )

      yield expense, admin, employee, category
    end
  ensure
    Apartment::Tenant.reset

    if subdomain && ActiveRecord::Base.connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end
  end

  def workflow_action(expense, admin, action, key)
    described_class.call(
      expense: expense,
      actor: admin,
      action: action,
      idempotency_key: key
    )
  end

  describe ".call" do
    %i[approve reject].each do |action|
      context "when action is #{action}" do
        it "returns bad request when the idempotency key is missing" do
          with_idempotency_tenant do |expense, admin, _employee, _category|
            result = workflow_action(expense, admin, action, nil)

            expect(result.value[:status]).to eq(:bad_request)
            expect(result.value[:body][:errors]).to include(
              "Idempotency-Key header is required"
            )

            expect(expense.reload.status).to eq("pending")
            expect(ReimbursementIdempotencyRecord.count).to eq(0)
          end
        end

        it "replays the original response for the same key and expense" do
          with_idempotency_tenant do |expense, admin, _employee, _category|
            key = "workflow-#{action}-123"

            first_result = workflow_action(expense, admin, action, key)
            second_result = workflow_action(expense, admin, action, key)

            expect(first_result.value[:status]).to eq(200)
            expect(second_result.value[:status]).to eq(
              first_result.value[:status]
            )
            expect(second_result.value[:body]).to eq(
              first_result.value[:body]
            )
            expect(second_result.value[:replayed]).to be(true)

            expected_status = action == :approve ? "approved" : "rejected"
            expect(expense.reload.status).to eq(expected_status)
          end
        end

        it "does not create another idempotency record on replay" do
          with_idempotency_tenant do |expense, admin, _employee, _category|
            key = "workflow-#{action}-456"

            workflow_action(expense, admin, action, key)

            expect do
              workflow_action(expense, admin, action, key)
            end.not_to change(ReimbursementIdempotencyRecord, :count)
          end
        end

        it "rejects a key already used for another expense" do
          with_idempotency_tenant do |expense, admin, employee, category|
            key = "shared-#{action}-key"

            workflow_action(expense, admin, action, key)

            another_expense = create(
              :expense,
              user: employee,
              category: category,
              status: "pending"
            )

            result = workflow_action(another_expense, admin, action, key)

            expect(result.value[:status]).to eq(:unprocessable_entity)
            expect(result.value[:body][:errors]).to include(
              "Idempotency-Key has already been used for another expense"
            )

            expect(another_expense.reload.status).to eq("pending")
          end
        end
      end
    end

    it "keeps approval and rejection keys separate" do
      with_idempotency_tenant do |expense, admin, _employee, _category|
        key = "shared-action-key"

        approval_result = workflow_action(expense, admin, :approve, key)

        expect(approval_result.value[:status]).to eq(200)

        rejection_result = workflow_action(expense, admin, :reject, key)

        expect(rejection_result.value[:status]).to eq(422)

        expect(rejection_result.value[:body]["errors"]).to be_present
        expect(expense.reload.status).to eq("approved")
      end
    end
  end
end
