require "rails_helper"
require Rails.root.join(
  "db/tenant_migrate/20261104120000_add_reference_number_to_expenses"
)

RSpec.describe AddReferenceNumberToExpenses do
  self.use_transactional_tests = false

  let(:company_a) do
    create(:company, subdomain: "reference_a_#{SecureRandom.hex(3)}")
  end

  let(:company_b) do
    create(:company, subdomain: "reference_b_#{SecureRandom.hex(3)}")
  end

  after do
    Apartment::Tenant.reset

    [ company_a, company_b ].each do |company|
      next unless company&.persisted?

      if ActiveRecord::Base.connection.schema_exists?(company.subdomain)
        Apartment::Tenant.drop(company.subdomain)
      end

      company.delete
    end
  end

  def prepare_tenant(company, expense_count:)
    connection = ActiveRecord::Base.connection

    connection.execute(
      "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
    )

    Apartment::Tenant.switch(company.subdomain) do
      migration_context = ActiveRecord::MigrationContext.new(
        Rails.root.join("db/tenant_migrate")
      )

      # Prepare the tenant at the version immediately before this migration.
      migration_context.migrate(20261104111000)

      Expense.reset_column_information

      user = create(:user, company: company, role: :member)
      category = create(:category)

      expense_ids = expense_count.times.map do
        create(
          :expense,
          user: user,
          category: category
        ).id
      end

      expense_ids
    end
  end

  it "backfills reference numbers across tenant schemas with different data volumes" do
    expected_a = prepare_tenant(company_a, expense_count: 3)
    expected_b = prepare_tenant(company_b, expense_count: 7)

    {
      company_a => expected_a,
      company_b => expected_b
    }.each do |company, expense_ids|
      Apartment::Tenant.switch(company.subdomain) do
        described_class.new.migrate(:up)

        Expense.reset_column_information

        expense_ids.each do |expense_id|
          expense = Expense.find(expense_id)

          expect(expense.reference_number).to eq("EXP-#{expense.id}")
        end

        # New expenses must also satisfy the validated constraint.
        user = User.first
        category = Category.first

        new_expense = create(
          :expense,
          user: user,
          category: category
        )

        expect(new_expense.reference_number).to be_present

        expect(
          ActiveRecord::Base.connection.check_constraints("expenses").map(&:name)
        ).to include("expenses_reference_number_not_null")
      end
    end
  end
end
