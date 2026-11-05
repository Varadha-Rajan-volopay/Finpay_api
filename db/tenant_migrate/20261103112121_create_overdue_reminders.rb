# frozen_string_literal: true

class CreateOverdueReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :overdue_reminders do |t|
      t.references :expense,
                   null: false,
                   foreign_key: true

      t.date :reminder_date, null: false

      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :overdue_reminders,
              [ :expense_id, :reminder_date ],
              unique: true,
              name: "index_overdue_reminders_on_expense_and_reminder_date"
  end
end
