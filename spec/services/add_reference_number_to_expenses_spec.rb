require "rails_helper"

require Rails.root.join(
  "db/tenant_migrate/20261104120000_add_reference_number_to_expenses"
)
require Rails.root.join(
  "db/tenant_migrate/20261105140000_backfill_and_constrain_expense_reference_numbers"
)

RSpec.describe AddReferenceNumberToExpenses do
  self.use_transactional_tests = false

  let(:company_a) do
    create(:company, subdomain: "reference_a_#{SecureRandom.hex(3)}")
  end

  after do
    Apartment::Tenant.reset

    if company_a&.persisted?
      if ActiveRecord::Base.connection.schema_exists?(company_a.subdomain)
        Apartment::Tenant.drop(company_a.subdomain)
      end

      company_a.delete
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

      migration_context.migrate(20261104120000)

      Expense.reset_column_information

      user = create(:user, company: company, role: :member)
      category = create(:category)

      expense_count.times.map do
        create(
          :expense,
          user: user,
          category: category
        ).id
      end
    end
  end

  it "backfills unique reference numbers across the tenant schema" do
    expense_ids = prepare_tenant(company_a, expense_count: 3)

    Apartment::Tenant.switch(company_a.subdomain) do
      migration_context = ActiveRecord::MigrationContext.new(
        Rails.root.join("db/tenant_migrate")
      )

      migration_context.migrate(20261105140000)

      Expense.reset_column_information

      expenses = Expense.where(id: expense_ids)

      reference_numbers = expenses.pluck(:reference_number)

      expect(reference_numbers).to all(match(/\AEXP-[0-9A-F]{32}\z/))
      expect(reference_numbers.uniq.size).to eq(3)

      expect(Expense.columns_hash["reference_number"].null).to be(false)

      unique_index = ActiveRecord::Base.connection.indexes("expenses").find do |index|
        index.name == "index_expenses_on_reference_number_unique"
      end

      expect(unique_index).to be_present

      first_expense = expenses.first
      user = User.first
      category = Category.first

      expect do
        create(
          :expense,
          user: user,
          category: category,
          reference_number: first_expense.reference_number
        )
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it "recovers when the reference number constraint was partially applied" do
    expense_ids = prepare_tenant(company_a, expense_count: 1)

    Apartment::Tenant.switch(company_a.subdomain) do
      migration_context = ActiveRecord::MigrationContext.new(
        Rails.root.join("db/tenant_migrate")
      )

      migration_context.migrate(20261105140000)

      Expense.reset_column_information

      connection = ActiveRecord::Base.connection
      expense = Expense.find(expense_ids.first)

      # Simulate a partially completed migration.
      connection.change_column_null(:expenses, :reference_number, true)
      expense.update_columns(reference_number: nil)

      connection.add_check_constraint(
        :expenses,
        "reference_number IS NOT NULL",
        name: "expenses_reference_number_not_null",
        validate: false
      )

      migration = BackfillAndConstrainExpenseReferenceNumbers.new

      expect { migration.up }.not_to raise_error

      Expense.reset_column_information
      expense.reload

      expect(expense.reference_number).to match(/\AEXP-[0-9A-F]{32}\z/)
      expect(Expense.columns_hash["reference_number"].null).to be(false)

      expect(
        connection.check_constraints("expenses").map(&:name)
      ).not_to include("expenses_reference_number_not_null")

      # Running it again must also be safe.
      expect { migration.up }.not_to raise_error
    end
  end
end
