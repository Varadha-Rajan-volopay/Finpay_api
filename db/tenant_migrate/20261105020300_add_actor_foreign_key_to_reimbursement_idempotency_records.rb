class AddActorForeignKeyToReimbursementIdempotencyRecords < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :reimbursement_idempotency_records,
                    :users,
                    column: :actor_id,
                    name: "fk_reimbursement_idempotency_records_actor",
                    validate: false
  end
end
