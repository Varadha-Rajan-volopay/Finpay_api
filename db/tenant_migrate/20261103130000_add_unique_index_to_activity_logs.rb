# frozen_string_literal: true

class AddUniqueIndexToActivityLogs < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :activity_logs,
              %i[expense_id actor_id action from_state to_state],
              unique: true,
              name: "index_activity_logs_on_expense_actor_action_states",
              algorithm: :concurrently
  end
end
