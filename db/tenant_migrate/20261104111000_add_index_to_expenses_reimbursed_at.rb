# frozen_string_literal: true

class AddIndexToExpensesReimbursedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :expenses,
              :reimbursed_at,
              algorithm: :concurrently
  end
end
