
require "rails_helper"
require Rails.root.join(
  "db/tenant_migrate/20261104110000_backfill_reimbursed_at_on_expenses"
)

RSpec.describe BackfillReimbursedAtOnExpenses do
  self.use_transactional_tests = false

  let(:company_a) do
    create(:company, subdomain: "backfill_a_#{SecureRandom.hex(3)}")
  end

  let(:company_b) do
    create(:company, subdomain: "backfill_b_#{SecureRandom.hex(3)}")
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

  def prepare_tenant(company, reimbursed_count:)
    connection = ActiveRecord::Base.connection

    connection.execute(
      "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
    )

    Companies::TenantMigration.run!(company.subdomain)

    Apartment::Tenant.switch(company.subdomain) do
      Expense.reset_column_information

      user = create(:user, company: company, role: :member)
      category = create(:category)

      expected_timestamps = reimbursed_count.times.map do |index|
        expense = create(
          :expense,
          user: user,
          category: category,
          status: "reimbursed"
        )

        timestamp = Time.zone.parse("2026-10-01 10:00:00") + index.minutes

        ActivityLog.create!(
          expense: expense,
          actor: user,
          action: "reimburse",
          from_state: "approved",
          to_state: "reimbursed",
          created_at: timestamp
        )

        expense.update_columns(
          reimbursed_at: nil,
          updated_at: timestamp
        )

        [ expense.id, timestamp ]
      end

      pending_expense = create(
        :expense,
        user: user,
        category: category,
        status: "pending",
        reimbursed_at: nil
      )

      {
        expected_timestamps: expected_timestamps,
        pending_id: pending_expense.id
      }
    end
  end

  it "backfills reimbursed expenses independently across tenant schemas" do
    data_a = prepare_tenant(company_a, reimbursed_count: 3)
    data_b = prepare_tenant(company_b, reimbursed_count: 7)

    [ company_a, company_b ].each do |company|
      Apartment::Tenant.switch(company.subdomain) do
        described_class.new.migrate(:up)
      end
    end

    {
      company_a => data_a,
      company_b => data_b
    }.each do |company, expected_data|
      Apartment::Tenant.switch(company.subdomain) do
        expected_data[:expected_timestamps].each do |expense_id, timestamp|
          expense = Expense.find(expense_id)

          expect(expense.reimbursed_at).to eq(timestamp)
        end

        pending_expense = Expense.find(expected_data[:pending_id])

        expect(pending_expense.reimbursed_at).to be_nil
      end
    end
  end
  it "backfills archived expenses using the reimbursement activity timestamp" do
    connection = ActiveRecord::Base.connection

    connection.execute(
      "CREATE SCHEMA #{connection.quote_table_name(company_a.subdomain)}"
    )

    Companies::TenantMigration.run!(company_a.subdomain)

    Apartment::Tenant.switch(company_a.subdomain) do
      Expense.reset_column_information

      user = create(:user, company: company_a, role: :member)
      category = create(:category)

      expense = create(
        :expense,
        user: user,
        category: category,
        status: "archived",
        reimbursed_at: nil
      )

      reimbursement_time = Time.zone.parse("2026-10-01 10:00:00")

      ActivityLog.create!(
        expense: expense,
        actor: user,
        action: "reimburse",
        from_state: "approved",
        to_state: "reimbursed",
        created_at: reimbursement_time
      )

      described_class.new.migrate(:up)

      expect(expense.reload.reimbursed_at).to eq(reimbursement_time)
    end
  end
end
