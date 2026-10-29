class ValidateExpenseConstraints < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :expenses, :users
    validate_foreign_key :expenses, :categories

    validate_check_constraint :expenses,
                              name: "expenses_amount_cents_positive"

    validate_check_constraint :expenses,
                              name: "expenses_currency_format"
  end
end
