class AddExpenseWorkflowTrackingAndFixIdempotencyIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Add workflow actor references and indexes concurrently.
    add_reference :expenses,
                  :approved_by,
                  null: true,
                  index: { algorithm: :concurrently }

    add_reference :expenses,
                  :rejected_by,
                  null: true,
                  index: { algorithm: :concurrently }

    add_reference :expenses,
                  :reimbursed_by,
                  null: true,
                  index: { algorithm: :concurrently }

    # Workflow timestamps.
    add_column :expenses, :approved_at, :datetime
    add_column :expenses, :rejected_at, :datetime
    add_column :expenses, :reimbursed_at, :datetime

    # Replace the old idempotency index concurrently.
    add_index :reimbursement_idempotency_records,
              [ :idempotency_key, :expense_id ],
              unique: true,
              name: "index_reimbursement_idempotency_records_on_key_and_expense",
              algorithm: :concurrently

    remove_index :reimbursement_idempotency_records,
                 name: "index_reimbursement_idempotency_records_on_key",
                 algorithm: :concurrently
  end
end
