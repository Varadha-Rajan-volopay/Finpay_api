require "rails_helper"

RSpec.describe ExpenseFilter do
  let(:category) { create(:category) }
  let(:another_category) { create(:category) }

  let!(:matching_expense) do
    create(
      :expense,
      category: category,
      status: "pending",
      incurred_on: Date.new(2026, 10, 15)
    )
  end

  let!(:different_category_expense) do
    create(
      :expense,
      category: another_category,
      status: "pending",
      incurred_on: Date.new(2026, 10, 15)
    )
  end

  let!(:different_status_expense) do
    create(
      :expense,
      category: category,
      status: "approved",
      incurred_on: Date.new(2026, 10, 15)
    )
  end

  let!(:earlier_expense) do
    create(
      :expense,
      category: category,
      status: "pending",
      incurred_on: Date.new(2026, 10, 5)
    )
  end

  let!(:later_expense) do
    create(
      :expense,
      category: category,
      status: "pending",
      incurred_on: Date.new(2026, 10, 25)
    )
  end

  describe "#call" do
    context "when filtering by category" do
      it "returns expenses belonging to the selected category" do
        result = described_class.new(
          Expense.all,
          { category_id: category.id }
        ).call

        expect(result).to include(matching_expense)
        expect(result).not_to include(different_category_expense)
      end
    end

    context "when filtering by status" do
      it "returns expenses with the selected status" do
        result = described_class.new(
          Expense.all,
          { status: "pending" }
        ).call

        expect(result).to include(matching_expense)
        expect(result).not_to include(different_status_expense)
      end
    end

    context "when filtering by from date" do
      it "returns expenses on or after the selected date" do
        result = described_class.new(
          Expense.all,
          { from: "2026-10-15" }
        ).call

        expect(result).to include(matching_expense)
        expect(result).not_to include(earlier_expense)
      end
    end

    context "when filtering by to date" do
      it "returns expenses on or before the selected date" do
        result = described_class.new(
          Expense.all,
          { to: "2026-10-15" }
        ).call

        expect(result).to include(matching_expense)
        expect(result).not_to include(later_expense)
      end
    end

    context "when applying all filters together" do
      it "returns only expenses matching every filter" do
        result = described_class.new(
          Expense.all,
          {
            category_id: category.id,
            status: "pending",
            from: "2026-10-10",
            to: "2026-10-20"
          }
        ).call

        expect(result).to contain_exactly(matching_expense)
      end
    end

    context "when an unknown filter is provided" do
      it "raises InvalidFilter" do
        expect do
          described_class.new(
            Expense.all,
            { unknown: "value" }
          ).call
        end.to raise_error(
          ExpenseFilter::InvalidFilter,
          /Unknown filters/
        )
      end
    end

    context "when an invalid category ID is provided" do
      it "raises InvalidFilter" do
        expect do
          described_class.new(
            Expense.all,
            { category_id: "invalid" }
          ).call
        end.to raise_error(
          ExpenseFilter::InvalidFilter,
          "Invalid category_id"
        )
      end
    end

    context "when an invalid status is provided" do
      it "raises InvalidFilter" do
        expect do
          described_class.new(
            Expense.all,
            { status: "invalid_status" }
          ).call
        end.to raise_error(
          ExpenseFilter::InvalidFilter,
          "Invalid status"
        )
      end
    end

    context "when the date format is invalid" do
      it "raises InvalidFilter" do
        expect do
          described_class.new(
            Expense.all,
            { from: "15-10-2026" }
          ).call
        end.to raise_error(
          ExpenseFilter::InvalidFilter,
          /YYYY-MM-DD/
        )
      end
    end

    context "when the from date is after the to date" do
      it "raises InvalidFilter" do
        expect do
          described_class.new(
            Expense.all,
            {
              from: "2026-10-20",
              to: "2026-10-10"
            }
          ).call
        end.to raise_error(
          ExpenseFilter::InvalidFilter,
          /cannot be after/
        )
      end
    end
  end
end
