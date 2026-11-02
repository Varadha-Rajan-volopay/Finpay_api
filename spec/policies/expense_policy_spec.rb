
require "rails_helper"

RSpec.describe ExpensePolicy do
  self.use_transactional_tests = false
  def with_policy_tenant
    subdomain = "policy#{SecureRandom.hex(4)}"

    Companies::Provision.call(
      name: "Policy Test Company",
      subdomain: subdomain
    ) do |company|
      employee = create(:user, company: company, role: :member)
      another_employee = create(:user, company: company, role: :member)
      admin = create(:user, company: company, role: :admin)
      category = create(:category)

      expense = create(
        :expense,
        user: employee,
        category: category,
        status: "pending"
      )

      yield expense, employee, another_employee, admin
    end
  ensure
    Apartment::Tenant.reset

    if subdomain && ActiveRecord::Base.connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end
  end

  describe "workflow permissions" do
    it "allows an admin to approve another user's expense" do
      with_policy_tenant do |expense, _employee, _another_employee, admin|
        policy = described_class.new(admin, expense)

        expect(policy.approve?).to be(true)
      end
    end

    it "does not allow an employee to approve an expense" do
      with_policy_tenant do |expense, employee, _another_employee, _admin|
        policy = described_class.new(employee, expense)

        expect(policy.approve?).to be(false)
      end
    end

    it "does not allow an admin to approve their own expense" do
      with_policy_tenant do |_expense, _employee, _another_employee, admin|
        own_expense = create(
          :expense,
          user: admin,
          category: create(:category),
          status: "pending"
        )

        policy = described_class.new(admin, own_expense)

        expect(policy.approve?).to be(false)
      end
    end

    it "allows an admin to reject an expense" do
      with_policy_tenant do |expense, _employee, _another_employee, admin|
        expect(described_class.new(admin, expense).reject?).to be(true)
      end
    end

    it "allows an admin to reimburse an expense" do
      with_policy_tenant do |expense, _employee, _another_employee, admin|
        expect(described_class.new(admin, expense).reimburse?).to be(true)
      end
    end

    it "allows an admin to archive an expense" do
      with_policy_tenant do |expense, _employee, _another_employee, admin|
        expect(described_class.new(admin, expense).archive?).to be(true)
      end
    end
  end

  describe "record permissions" do
    it "allows the owner to show their expense" do
      with_policy_tenant do |expense, employee, _another_employee, _admin|
        expect(described_class.new(employee, expense).show?).to be(true)
      end
    end

    it "does not allow another employee to show the expense" do
      with_policy_tenant do |expense, _employee, another_employee, _admin|
        expect(described_class.new(another_employee, expense).show?).to be(false)
      end
    end

    it "allows an admin to show an expense" do
      with_policy_tenant do |expense, _employee, _another_employee, admin|
        expect(described_class.new(admin, expense).show?).to be(true)
      end
    end

    it "allows the owner to update a pending expense" do
      with_policy_tenant do |expense, employee, _another_employee, _admin|
        expect(described_class.new(employee, expense).update?).to be(true)
      end
    end

    it "does not allow the owner to update an approved expense" do
      with_policy_tenant do |expense, employee, _another_employee, _admin|
        expense.update!(status: "approved")

        expect(described_class.new(employee, expense).update?).to be(false)
      end
    end

    it "allows the owner to destroy a pending expense" do
      with_policy_tenant do |expense, employee, _another_employee, _admin|
        expect(described_class.new(employee, expense).destroy?).to be(true)
      end
    end

    it "does not allow the owner to destroy an approved expense" do
      with_policy_tenant do |expense, employee, _another_employee, _admin|
        expense.update!(status: "approved")

        expect(described_class.new(employee, expense).destroy?).to be(false)
      end
    end
  end

  describe "scope" do
    it "returns only the employee's own expenses" do
      with_policy_tenant do |expense, employee, another_employee, _admin|
        another_expense = create(
          :expense,
          user: another_employee,
          category: expense.category,
          status: "pending"
        )

        scoped_expenses = described_class::Scope
          .new(employee, Expense)
          .resolve

        expect(scoped_expenses).to include(expense)
        expect(scoped_expenses).not_to include(another_expense)
      end
    end

    it "allows an admin to see all tenant expenses" do
      with_policy_tenant do |expense, employee, _another_employee, admin|
        another_expense = create(
          :expense,
          user: employee,
          category: expense.category,
          status: "pending"
        )

        scoped_expenses = described_class::Scope
          .new(admin, Expense)
          .resolve

        expect(scoped_expenses).to include(expense, another_expense)
      end
    end
  end
end
