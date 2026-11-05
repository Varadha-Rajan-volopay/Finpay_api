class AddExpenseConstraintsSafely < ActiveRecord::Migration[8.1]
  def change
    # Add foreign keys without validating existing rows immediately.
    add_foreign_key :expenses, :users, validate: false
    add_foreign_key :expenses, :categories, validate: false

    # Add database-level financial constraints.
    add_check_constraint :expenses,
                         "amount_cents > 0",
                         name: "expenses_amount_cents_positive",
                         validate: false

    add_check_constraint :expenses,
                         "currency ~ '^[A-Z]{3}$'",
                         name: "expenses_currency_format",
                         validate: false
  end
end
