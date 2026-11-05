require "rails_helper"

RSpec.describe ExpenseWorkflowService do
  self.use_transactional_tests = false

  def with_workflow_tenant
    subdomain = "workflow#{SecureRandom.hex(4)}"

    Companies::Provision.call(
      name: "Workflow Test Company",
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

      yield expense, admin, employee
    end
  ensure
    Apartment::Tenant.reset

    if subdomain && ActiveRecord::Base.connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end
  end

  describe ".call" do
    it "approves a pending expense" do
      with_workflow_tenant do |expense, admin, _employee|
        result = described_class.call(
          expense: expense,
          actor: admin,
          action: :approve
        )

        expect(result).to be_success
        expect(expense.reload.status).to eq("approved")
      end
    end

    it "rejects a pending expense" do
      with_workflow_tenant do |expense, admin, _employee|
        result = described_class.call(
          expense: expense,
          actor: admin,
          action: :reject
        )

        expect(result).to be_success
        expect(expense.reload.status).to eq("rejected")
      end
    end

    it "reimburses an approved expense" do
      with_workflow_tenant do |expense, admin, _employee|
        expense.update!(status: "approved")

        result = described_class.call(
          expense: expense,
          actor: admin,
          action: :reimburse
        )

        expect(result).to be_success
        expect(expense.reload.status).to eq("reimbursed")
      end
    end

    it "archives a reimbursed expense" do
      with_workflow_tenant do |expense, admin, _employee|
        expense.update!(status: "reimbursed")

        result = described_class.call(
          expense: expense,
          actor: admin,
          action: :archive
        )

        expect(result).to be_success
        expect(expense.reload.status).to eq("archived")
      end
    end

    it "does not reimburse a pending expense" do
      with_workflow_tenant do |expense, admin, _employee|
        expect do
          described_class.call(
            expense: expense,
            actor: admin,
            action: :reimburse
          )
        end.to raise_error(
          Errors::InvalidTransition,
          "Cannot reimburse an expense from pending status"
        )

        expect(expense.reload.status).to eq("pending")
      end
    end

    it "does not approve an already approved expense" do
      with_workflow_tenant do |expense, admin, _employee|
        expense.update!(status: "approved")

        expect do
          described_class.call(
            expense: expense,
            actor: admin,
            action: :approve
          )
        end.to raise_error(
          Errors::InvalidTransition,
          "Cannot approve an expense from approved status"
        )

        expect(expense.reload.status).to eq("approved")
      end
    end

    it "does not reject an already approved expense" do
      with_workflow_tenant do |expense, admin, _employee|
        expense.update!(status: "approved")

        expect do
          described_class.call(
            expense: expense,
            actor: admin,
            action: :reject
          )
        end.to raise_error(
          Errors::InvalidTransition,
          "Cannot reject an expense from approved status"
        )

        expect(expense.reload.status).to eq("approved")
      end
    end

    it "does not archive a pending expense" do
      with_workflow_tenant do |expense, admin, _employee|
        expect do
          described_class.call(
            expense: expense,
            actor: admin,
            action: :archive
          )
        end.to raise_error(
          Errors::InvalidTransition,
          "Cannot archive an expense from pending status"
        )

        expect(expense.reload.status).to eq("pending")
      end
    end

    it "rolls back the workflow transition when activity logging fails" do
      with_workflow_tenant do |expense, admin, _employee|
        allow(ActivityLog).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid.new(ActivityLog.new))

        expect do
          described_class.call(
            expense: expense,
            actor: admin,
            action: :approve
          )
        end.to raise_error(ActiveRecord::RecordInvalid)

        expect(expense.reload.status).to eq("pending")
        expect(expense.reload.approved_by_id).to be_nil
        expect(expense.reload.approved_at).to be_nil
      end
    end

    it "rejects an unknown action" do
      with_workflow_tenant do |expense, admin, _employee|
        expect do
          described_class.call(
            expense: expense,
            actor: admin,
            action: :delete
          )
        end.to raise_error(
          Errors::InvalidTransition,
          "Invalid workflow action: delete"
        )


        expect(expense.reload.status).to eq("pending")
      end
    end
  end
end
