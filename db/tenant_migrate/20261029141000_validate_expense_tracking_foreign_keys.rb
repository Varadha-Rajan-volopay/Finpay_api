class ValidateExpenseTrackingForeignKeys < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    validate_foreign_key :expenses, :users
    validate_foreign_key :expenses, :categories
    validate_foreign_key :receipts, :expenses
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Validated expense-tracking foreign keys require a deliberate rollback."
  end
end
