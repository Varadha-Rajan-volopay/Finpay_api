class ValidateExpenseWorkflowForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :expenses, :users, column: :approved_by_id
    validate_foreign_key :expenses, :users, column: :rejected_by_id
    validate_foreign_key :expenses, :users, column: :reimbursed_by_id
  end
end
