# frozen_string_literal: true

class BackfillReimbursedAtOnExpenses < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class ExpenseRecord < ActiveRecord::Base
    self.table_name = "expenses"
  end

  def up
    ExpenseRecord
      .where(status: %w[reimbursed archived], reimbursed_at: nil)
      .where(<<~SQL.squish)
        EXISTS (
          SELECT 1
          FROM activity_logs
          WHERE activity_logs.expense_id = expenses.id
            AND activity_logs.action = 'reimburse'
        )
      SQL
      .in_batches(of: 1_000) do |batch|
        batch.update_all(<<~SQL.squish)
          reimbursed_at = (
            SELECT MIN(activity_logs.created_at)
            FROM activity_logs
            WHERE activity_logs.expense_id = expenses.id
              AND activity_logs.action = 'reimburse'
          )
        SQL

        sleep(0.01)
      end
  end

  def down
    ExpenseRecord
      .where(status: %w[reimbursed archived])
      .where(<<~SQL.squish)
        reimbursed_at = (
          SELECT MIN(activity_logs.created_at)
          FROM activity_logs
          WHERE activity_logs.expense_id = expenses.id
            AND activity_logs.action = 'reimburse'
        )
      SQL
      .in_batches(of: 1_000) do |batch|
        batch.update_all(reimbursed_at: nil)
        sleep(0.01)
      end
  end
end
