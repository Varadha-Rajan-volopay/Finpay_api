class AddExpenseConstraintsSafely < ActiveRecord::Migration[8.1]
  def change
    # Users are tenant-specific. Expenses are in the public schema,
    # so a public-schema foreign key to tenant users is not valid.
    add_foreign_key :expenses, :categories, validate: false

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
