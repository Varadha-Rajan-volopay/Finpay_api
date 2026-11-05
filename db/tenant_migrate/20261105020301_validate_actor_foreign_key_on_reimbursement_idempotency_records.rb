class ValidateActorForeignKeyOnReimbursementIdempotencyRecords < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :reimbursement_idempotency_records,
                         :users,
                         name: "fk_reimbursement_idempotency_records_actor"
  end
end
