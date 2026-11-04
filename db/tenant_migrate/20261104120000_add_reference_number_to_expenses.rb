# frozen_string_literal: true

class AddReferenceNumberToExpenses < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  CONSTRAINT_NAME = "expenses_reference_number_not_null"

  def up
    add_column :expenses, :reference_number, :string

    Expense.reset_column_information

    Expense.unscoped
           .where(reference_number: nil)
           .in_batches(of: 1_000) do |batch|
      batch.update_all("reference_number = 'EXP-' || id::text")
      sleep(0.01)
    end

    add_check_constraint(
      :expenses,
      "reference_number IS NOT NULL",
      name: CONSTRAINT_NAME,
      validate: false
    )

    validate_check_constraint(
      :expenses,
      name: CONSTRAINT_NAME
    )
  end

  def down
    remove_check_constraint(
      :expenses,
      name: CONSTRAINT_NAME
    )

    # Rolling back removes the generated reference numbers and their data.
    safety_assured do
      remove_column :expenses, :reference_number
    end
  end
end
