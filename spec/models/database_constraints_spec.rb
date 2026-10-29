require "rails_helper"

RSpec.describe "Database constraints", type: :model do
  let!(:user) { create(:user) }
  let!(:category) { create(:category) }

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

      expect do
        Expense.insert!(attributes)
      end.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects negative amount_cents" do
      attributes = valid_attributes.merge(amount_cents: -100)

      expect do
        Expense.insert!(attributes)
      end.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects an invalid currency format" do
      attributes = valid_attributes.merge(currency: "inr")

      expect do
        Expense.insert!(attributes)
      end.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects a currency longer than three characters" do
      attributes = valid_attributes.merge(currency: "INRR")

      expect do
        Expense.insert!(attributes)
      end.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects a null title" do
      attributes = valid_attributes.merge(title: nil)

      expect do
        Expense.insert!(attributes)
      end.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects a null amount_cents" do
      attributes = valid_attributes.merge(amount_cents: nil)

      expect do
        Expense.insert!(attributes)
      end.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "categories" do
    it "rejects duplicate names" do
      create(:category, name: "Travel")

      expect do
        Category.insert!(
          {
            name: "Travel",
            created_at: Time.current,
            updated_at: Time.current
          }
        )
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "receipts" do
    it "rejects a nonexistent expense_id" do
      expect do
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
      end.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
