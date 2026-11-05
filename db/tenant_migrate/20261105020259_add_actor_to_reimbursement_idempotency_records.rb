class AddActorToReimbursementIdempotencyRecords < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_reference :reimbursement_idempotency_records,
                  :actor,
                  null: false,
                  index: false

    add_index :reimbursement_idempotency_records,
              [ :actor_id, :idempotency_key ],
              unique: true,
              name: "index_reimbursement_idempotency_records_on_actor_and_key",
              algorithm: :concurrently

    remove_index :reimbursement_idempotency_records,
                 name: "index_reimbursement_idempotency_records_on_key_and_expense",
                 algorithm: :concurrently
  end

  def down
    remove_index :reimbursement_idempotency_records,
                 name: "index_reimbursement_idempotency_records_on_actor_and_key",
                 algorithm: :concurrently

    remove_reference :reimbursement_idempotency_records, :actor

    add_index :reimbursement_idempotency_records,
              [ :idempotency_key, :expense_id ],
              unique: true,
              name: "index_reimbursement_idempotency_records_on_key_and_expense",
              algorithm: :concurrently
  end
end
