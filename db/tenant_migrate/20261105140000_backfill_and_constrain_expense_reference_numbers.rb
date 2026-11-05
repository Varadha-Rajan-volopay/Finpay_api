
# frozen_string_literal: true

class BackfillAndConstrainExpenseReferenceNumbers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  CONSTRAINT_NAME = "expenses_reference_number_not_null"

  class ExpenseRecord < ActiveRecord::Base
    self.table_name = "expenses"
  end

  def up
    ExpenseRecord
      .where(reference_number: nil)
      .in_batches(of: 1_000) do |batch|
        batch.update_all(
          "reference_number = 'EXP-' || " \
          "upper(replace(gen_random_uuid()::text, '-', ''))"
        )
        sleep(0.01)
      end

    unless check_constraint_exists?(:expenses, name: CONSTRAINT_NAME)
      add_check_constraint(
        :expenses,
        "reference_number IS NOT NULL",
        name: CONSTRAINT_NAME,
        validate: false
      )
    end

    validate_check_constraint(:expenses, name: CONSTRAINT_NAME)

    change_column_null :expenses, :reference_number, false

    if check_constraint_exists?(:expenses, name: CONSTRAINT_NAME)
      remove_check_constraint(:expenses, name: CONSTRAINT_NAME)
    end
  end

  def down
    change_column_null :expenses, :reference_number, true

    if check_constraint_exists?(:expenses, name: CONSTRAINT_NAME)
      remove_check_constraint(:expenses, name: CONSTRAINT_NAME)
    end
  end
end
