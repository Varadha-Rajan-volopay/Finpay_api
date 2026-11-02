class CreateReimbursementIdempotencyRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :reimbursement_idempotency_records do |t|
      t.string :idempotency_key, null: false
      t.references :expense, null: false, foreign_key: true

      t.jsonb :response_body, null: false
      t.integer :response_status, null: false

      t.timestamps
    end

    add_index :reimbursement_idempotency_records,
              :idempotency_key,
              unique: true,
              name: "index_reimbursement_idempotency_records_on_key"
  end
end
