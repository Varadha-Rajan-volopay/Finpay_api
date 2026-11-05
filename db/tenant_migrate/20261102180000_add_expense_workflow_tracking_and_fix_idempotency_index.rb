class AddExpenseWorkflowTrackingAndFixIdempotencyIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
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

    add_column :expenses, :approved_at, :datetime
    add_column :expenses, :rejected_at, :datetime
    add_column :expenses, :reimbursed_at, :datetime

    add_index :reimbursement_idempotency_records,
              [ :idempotency_key, :expense_id ],
              unique: true,
              name: "index_reimbursement_idempotency_records_on_key_and_expense",
              algorithm: :concurrently

    remove_index :reimbursement_idempotency_records,
                 name: "index_reimbursement_idempotency_records_on_key",
                 algorithm: :concurrently
  end

  def down
    add_index :reimbursement_idempotency_records,
              :idempotency_key,
              unique: true,
              name: "index_reimbursement_idempotency_records_on_key",
              algorithm: :concurrently

    remove_index :reimbursement_idempotency_records,
                 name: "index_reimbursement_idempotency_records_on_key_and_expense",
                 algorithm: :concurrently

    remove_column :expenses, :reimbursed_at
    remove_column :expenses, :rejected_at
    remove_column :expenses, :approved_at

    remove_reference :expenses, :reimbursed_by, index: false
    remove_reference :expenses, :rejected_by, index: false
    remove_reference :expenses, :approved_by, index: false
  end
end
