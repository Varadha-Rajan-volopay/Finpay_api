# frozen_string_literal: true

class ExpensePresenter
  def initialize(expense)
    @expense = expense
  end

  def amount_display
    whole_units, minor_units = @expense.amount_cents.divmod(100)

    "#{whole_units}.#{minor_units.to_s.rjust(2, '0')}"
  end

  def category_name
    @expense.category.name
  end
end
