
# frozen_string_literal: true

class BackfillReimbursedAtOnExpenses < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    Expense.unscoped
           .where(status: "reimbursed", reimbursed_at: nil)
           .in_batches(of: 1_000) do |batch|
      batch.update_all("reimbursed_at = updated_at")
      sleep(0.01)
    end
  end

  def down
    # Clears backfilled values that still match updated_at.
    # Exact reversal is not guaranteed because the original nil values
    # were not separately recorded. A pre-existing value equal to
    # updated_at may also be cleared.
    Expense.unscoped
           .where(status: "reimbursed")
           .where("reimbursed_at = updated_at")
           .in_batches(of: 1_000) do |batch|
      batch.update_all(reimbursed_at: nil)
      sleep(0.01)
    end
  end
end
