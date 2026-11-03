require "rails_helper"

RSpec.describe "Database constraints", type: :model do
  self.use_transactional_tests = false

  around do |example|
    subdomain = "constraints_#{SecureRandom.hex(6)}"
    company = nil

    begin
      Companies::Provision.call(
        name: "Constraints Test Company",
        subdomain: subdomain
      ) do |provisioned_company|
        company = provisioned_company
        @tenant_company = provisioned_company

        example.run
      end
    ensure
      Apartment::Tenant.reset

      if ActiveRecord::Base.connection.schema_exists?(subdomain)
        Apartment::Tenant.drop(subdomain)
      end

      company&.delete
      @tenant_company = nil
    end
  end

  let!(:user) { create(:user, company: @tenant_company) }
  let!(:category) { create(:category) }

  # Runs a database constraint violation inside a savepoint.
  # This prevents a failed SQL statement from aborting the
  # surrounding test transaction.
  def expect_constraint_violation(error_class = ActiveRecord::StatementInvalid)
    expect do
      ActiveRecord::Base.transaction(requires_new: true) do
        yield
      end
    end.to raise_error(error_class)
  end

  describe "expenses" do
    let(:valid_attributes) do
      {
        user_id: user.id,
        category_id: category.id,
        title: "Lunch",
        amount_cents: 1_050,
        currency: "INR",
        status: "pending",
        incurred_on: Date.current,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    it "rejects zero amount_cents" do
      attributes = valid_attributes.merge(amount_cents: 0)

      expect_constraint_violation do
        Expense.insert!(attributes)
      end
    end

    it "rejects negative amount_cents" do
      attributes = valid_attributes.merge(amount_cents: -100)

      expect_constraint_violation do
        Expense.insert!(attributes)
      end
    end

    it "rejects an invalid currency format" do
      attributes = valid_attributes.merge(currency: "inr")

      expect_constraint_violation do
        Expense.insert!(attributes)
      end
    end

    it "rejects a currency longer than three characters" do
      attributes = valid_attributes.merge(currency: "INRR")

      expect_constraint_violation do
        Expense.insert!(attributes)
      end
    end

    it "rejects a null title" do
      attributes = valid_attributes.merge(title: nil)

      expect_constraint_violation do
        Expense.insert!(attributes)
      end
    end

    it "rejects a null amount_cents" do
      attributes = valid_attributes.merge(amount_cents: nil)

      expect_constraint_violation do
        Expense.insert!(attributes)
      end
    end
  end

  describe "categories" do
    it "rejects duplicate names" do
      create(:category, name: "Travel")

      expect_constraint_violation(ActiveRecord::RecordNotUnique) do
        Category.insert!(
          {
            name: "Travel",
            created_at: Time.current,
            updated_at: Time.current
          }
        )
      end
    end
  end

  describe "receipts" do
    it "rejects a nonexistent expense_id" do
      expect_constraint_violation(ActiveRecord::InvalidForeignKey) do
        Receipt.insert!(
          {
            expense_id: -1,
            file_name: "receipt.pdf",
            content_type: "application/pdf",
            byte_size: 1_024,
            storage_key: "receipts/test.pdf",
            ocr_status: "pending",
            created_at: Time.current,
            updated_at: Time.current
          }
        )
      end
    end
  end
end
