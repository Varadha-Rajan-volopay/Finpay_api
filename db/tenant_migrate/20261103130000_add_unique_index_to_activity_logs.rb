# frozen_string_literal: true

class AddUniqueIndexToActivityLogs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_activity_logs_on_expense_actor_action_states"

  def up
    duplicates = select_value(<<~SQL)
      SELECT EXISTS (
        SELECT 1
        FROM activity_logs
        GROUP BY expense_id, actor_id, action, from_state, to_state
        HAVING COUNT(*) > 1
      )
    SQL

    if ActiveModel::Type::Boolean.new.cast(duplicates)
      raise "Duplicate activity logs exist. Resolve them before creating the unique index."
    end

    add_index :activity_logs,
              %i[expense_id actor_id action from_state to_state],
              unique: true,
              name: INDEX_NAME,
              algorithm: :concurrently
  end

  def down
    remove_index :activity_logs,
                 name: INDEX_NAME,
                 algorithm: :concurrently
  end
end
