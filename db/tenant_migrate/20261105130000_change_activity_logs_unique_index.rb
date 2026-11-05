# frozen_string_literal: true

class ChangeActivityLogsUniqueIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  OLD_INDEX = "index_activity_logs_on_expense_actor_action_states"
  NEW_INDEX = "index_activity_logs_on_event_details_and_created_at"

  def up
    duplicates = select_value(<<~SQL)
      SELECT EXISTS (
        SELECT 1
        FROM activity_logs
        GROUP BY expense_id, actor_id, action, from_state, to_state, created_at
        HAVING COUNT(*) > 1
      )
    SQL

    if ActiveModel::Type::Boolean.new.cast(duplicates)
      raise "Duplicate activity log events exist. Resolve them before creating the unique index."
    end

    if index_exists?(:activity_logs, name: OLD_INDEX)
      remove_index :activity_logs,
                   name: OLD_INDEX,
                   algorithm: :concurrently
    end

    add_index :activity_logs,
              %i[
                expense_id
                actor_id
                action
                from_state
                to_state
                created_at
              ],
              unique: true,
              name: NEW_INDEX,
              algorithm: :concurrently
  end

  def down
    remove_index :activity_logs,
                 name: NEW_INDEX,
                 algorithm: :concurrently

    add_index :activity_logs,
              %i[expense_id actor_id action from_state to_state],
              unique: true,
              name: OLD_INDEX,
              algorithm: :concurrently
  end
end
