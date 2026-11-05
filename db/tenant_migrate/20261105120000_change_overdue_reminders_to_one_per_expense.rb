
# frozen_string_literal: true

class ChangeOverdueRemindersToOnePerExpense < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  OLD_INDEX = "index_overdue_reminders_on_expense_and_reminder_date"
  NEW_INDEX = "index_overdue_reminders_on_expense_id"

  def up
    remove_duplicate_reminders

    if index_exists?(:overdue_reminders, name: OLD_INDEX)
      remove_index :overdue_reminders,
                   name: OLD_INDEX,
                   algorithm: :concurrently
    end

    return if index_valid?(NEW_INDEX)

    if index_exists?(:overdue_reminders, name: NEW_INDEX)
      remove_index :overdue_reminders,
                   name: NEW_INDEX,
                   algorithm: :concurrently
    end

    add_index :overdue_reminders,
              :expense_id,
              unique: true,
              name: NEW_INDEX,
              algorithm: :concurrently
  end

  def down
    if index_exists?(:overdue_reminders, name: NEW_INDEX)
      remove_index :overdue_reminders,
                   name: NEW_INDEX,
                   algorithm: :concurrently
    end

    unless index_exists?(:overdue_reminders, name: OLD_INDEX)
      add_index :overdue_reminders,
                [ :expense_id, :reminder_date ],
                unique: true,
                name: OLD_INDEX,
                algorithm: :concurrently
    end
  end

  private

  def remove_duplicate_reminders
    safety_assured do
      execute <<~SQL
        DELETE FROM overdue_reminders
        WHERE id IN (
          SELECT id
          FROM (
            SELECT
              id,
              ROW_NUMBER() OVER (
                PARTITION BY expense_id
                ORDER BY reminder_date DESC, created_at DESC, id DESC
              ) AS row_number
            FROM overdue_reminders
          ) ranked
          WHERE row_number > 1
        )
      SQL
    end
  end

  def index_valid?(index_name)
    result = select_one(
        <<~SQL
        SELECT i.indisvalid, i.indisunique
        FROM pg_class c
        JOIN pg_index i ON i.indexrelid = c.oid
        WHERE c.relname = #{connection.quote(index_name)}
            AND pg_table_is_visible(c.oid)
        SQL
    )

    result.present? &&
        result["indisvalid"] == true &&
        result["indisunique"] == true
    end
end
