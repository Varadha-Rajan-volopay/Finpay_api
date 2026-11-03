
require "rails_helper"

RSpec.describe ExpenseWorkflowService do
  self.use_transactional_tests = false
  def with_audit_tenant
    subdomain = "audit#{SecureRandom.hex(4)}"

    Companies::Provision.call(
      name: "Audit Test Company",
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

      yield expense, admin
    end
  ensure
    Apartment::Tenant.reset

    if subdomain && ActiveRecord::Base.connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end
  end

  describe "audit logging" do
    it "records the actor and state transition when an expense is approved" do
      with_audit_tenant do |expense, admin|
        expect do
          described_class.call(
            expense: expense,
            actor: admin,
            action: :approve
          )
        end.to change(ActivityLog, :count).by(1)

        log = ActivityLog.last

        expect(log.expense_id).to eq(expense.id)
        expect(log.actor_id).to eq(admin.id)
        expect(log.action).to eq("approve")
        expect(log.from_state).to eq("pending")
        expect(log.to_state).to eq("approved")
      end
    end

    it "does not create an audit log for an invalid transition" do
      with_audit_tenant do |expense, admin|
        expect do
          described_class.call(
            expense: expense,
            actor: admin,
            action: :reimburse
          )
        end.not_to change(ActivityLog, :count)

        expect(expense.reload.status).to eq("pending")
      end
    end

    it "does not allow an audit log to be updated" do
      with_audit_tenant do |expense, admin|
        described_class.call(
          expense: expense,
          actor: admin,
          action: :approve
        )

        log = ActivityLog.last

        expect do
          log.update!(action: "changed")
        end.to raise_error(ActiveRecord::ReadOnlyRecord)
      end
    end

    it "does not allow an audit log to be deleted" do
      with_audit_tenant do |expense, admin|
        described_class.call(
          expense: expense,
          actor: admin,
          action: :approve
        )

        log = ActivityLog.last

        expect do
          log.destroy!
        end.to raise_error(ActiveRecord::ReadOnlyRecord)
      end
    end
  end
end
