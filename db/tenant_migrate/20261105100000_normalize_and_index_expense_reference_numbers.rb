# frozen_string_literal: true

class NormalizeAndIndexExpenseReferenceNumbers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_expenses_on_reference_number_unique"

  class ExpenseReferenceNumberRecord < ActiveRecord::Base
    self.table_name = "expenses"
  end

  def up
    ExpenseReferenceNumberRecord.unscoped
      .where(
        "reference_number IS NULL OR reference_number !~ ?",
        "^EXP-[0-9A-F]{32}$"
      )
      .in_batches(of: 1_000) do |batch|
        batch.update_all(
          "reference_number = 'EXP-' || " \
          "upper(replace(gen_random_uuid()::text, '-', ''))"
        )

        sleep(0.01)
      end

    add_index :expenses,
              :reference_number,
              unique: true,
              name: INDEX_NAME,
              algorithm: :concurrently
  end

  def down
    remove_index :expenses,
                 name: INDEX_NAME,
                 algorithm: :concurrently
  end
end
