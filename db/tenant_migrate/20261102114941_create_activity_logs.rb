class CreateActivityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_logs do |t|
      t.references :expense,
                   null: false,
                   foreign_key: true

      t.references :actor,
                   null: false,
                   foreign_key: { to_table: :users }

      t.string :action, null: false
      t.string :from_state, null: false
      t.string :to_state, null: false

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :activity_logs, :created_at
  end
end
