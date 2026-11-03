class AddExpenseWorkflowForeignKeys < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :expenses,
                    :users,
                    column: :approved_by_id,
                    validate: false

    add_foreign_key :expenses,
                    :users,
                    column: :rejected_by_id,
                    validate: false

    add_foreign_key :expenses,
                    :users,
                    column: :reimbursed_by_id,
                    validate: false
  end
end
