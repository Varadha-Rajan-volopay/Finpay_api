
require "rails_helper"

RSpec.describe Expense, type: :model do
  self.use_transactional_tests = false

  around do |example|
    subdomain = "expense_spec#{SecureRandom.hex(6)}"
    company = nil

    begin
      Companies::Provision.call(
        name: "Expense Model Test Company",
        subdomain: subdomain
      ) do |provisioned_company|
        company = provisioned_company
        example.run
      end
    ensure
      Apartment::Tenant.reset

      if ActiveRecord::Base.connection.schema_exists?(subdomain)
        Apartment::Tenant.drop(subdomain)
      end

      company&.delete
    end
  end

  describe "Money rules" do
    describe ".amount_cents_from" do
      it "converts a decimal amount into minor units" do
        expect(
          described_class.amount_cents_from("10.50", currency: "INR")
        ).to eq(1050)
      end

      it "rejects amounts with excess decimal places" do
        expect {
          described_class.amount_cents_from("10.555", currency: "INR")
        }.to raise_error(
          ArgumentError,
          "Amount has too many decimal places for INR"
        )
      end

      it "rejects unsupported currencies" do
        expect {
          described_class.amount_cents_from("10.50", currency: "XYZ")
        }.to raise_error(ArgumentError, "Unsupported currency")
      end

      it "rejects negative amounts" do
        expect {
          described_class.amount_cents_from("-10.50", currency: "INR")
        }.to raise_error(ArgumentError)
      end

      it "rejects non-numeric input" do
        expect {
          described_class.amount_cents_from("abc", currency: "INR")
        }.to raise_error(ArgumentError)
      end

      it "rejects amounts with a trailing decimal point" do
        expect {
          described_class.amount_cents_from("10.", currency: "INR")
        }.to raise_error(ArgumentError)
      end
    end

    describe ".round_to_minor_units" do
      it "rounds half-up when the third decimal is 5" do
        expect(
          described_class.round_to_minor_units("1.005", currency: "INR")
        ).to eq(101)
      end

      it "does not round up when the third decimal is below 5" do
        expect(
          described_class.round_to_minor_units("1.004", currency: "INR")
        ).to eq(100)
      end

      it "rejects negative amounts" do
        expect {
          described_class.round_to_minor_units("-10.50", currency: "INR")
        }.to raise_error(
          ArgumentError,
          "Amount must be a finite, non-negative decimal"
        )
      end

      it "rejects NaN amounts" do
        expect {
          described_class.round_to_minor_units("NaN", currency: "INR")
        }.to raise_error(
          ArgumentError,
          "Amount must be a finite, non-negative decimal"
        )
      end

      it "rejects infinite amounts" do
        expect {
          described_class.round_to_minor_units("Infinity", currency: "INR")
        }.to raise_error(
          ArgumentError,
          "Amount must be a finite, non-negative decimal"
        )
      end

      it "rejects invalid decimal input" do
        expect {
          described_class.round_to_minor_units("abc", currency: "INR")
        }.to raise_error(
          ArgumentError,
          "Amount must be a finite, non-negative decimal"
        )
      end

      it "rejects unsupported currencies" do
        expect {
          described_class.round_to_minor_units("10.50", currency: "XYZ")
        }.to raise_error(ArgumentError, "Unsupported currency")
      end
    end

    describe "amount_cents validation" do
      it "rejects zero" do
        expense = build(:expense, amount_cents: 0)

        expect(expense).not_to be_valid
        expect(expense.errors[:amount_cents]).to be_present
      end

      it "rejects negative amounts" do
        expense = build(:expense, amount_cents: -100)

        expect(expense).not_to be_valid
        expect(expense.errors[:amount_cents]).to be_present
      end
    end
  end

  describe "validations" do
    it "requires a title" do
      expense = build(:expense, title: nil)

      expect(expense).not_to be_valid
      expect(expense.errors[:title]).to be_present
    end

    it "requires a supported currency" do
      expense = build(:expense, currency: "XYZ")

      expect(expense).not_to be_valid
      expect(expense.errors[:currency]).to be_present
    end

    it "requires an incurred date" do
      expense = build(:expense, incurred_on: nil)

      expect(expense).not_to be_valid
      expect(expense.errors[:incurred_on]).to be_present
    end

    it "requires a valid status" do
      expense = build(:expense, status: "invalid")

      expect(expense).not_to be_valid
      expect(expense.errors[:status]).to be_present
    end
  end

  describe "associations" do
    it "belongs to a user" do
      association = described_class.reflect_on_association(:user)

      expect(association.macro).to eq(:belongs_to)
    end

    it "belongs to a category" do
      association = described_class.reflect_on_association(:category)

      expect(association.macro).to eq(:belongs_to)
    end

    it "has many receipts with dependent destroy" do
      association = described_class.reflect_on_association(:receipts)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe "scopes" do
    let!(:pending_expense) { create(:expense, status: "pending") }
    let!(:approved_expense) { create(:expense, status: "approved") }

    it "returns pending expenses" do
      expect(described_class.pending).to include(pending_expense)
      expect(described_class.pending).not_to include(approved_expense)
    end

    it "returns expenses for a user" do
      user = pending_expense.user

      expect(described_class.for_user(user)).to include(pending_expense)

      if approved_expense.user != user
        expect(described_class.for_user(user)).not_to include(approved_expense)
      end
    end

    it "returns expenses for a month" do
      expect(
        described_class.for_month(pending_expense.incurred_on)
      ).to include(pending_expense)
    end
  end
end
