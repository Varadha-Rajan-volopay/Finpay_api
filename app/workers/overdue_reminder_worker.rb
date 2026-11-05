
# frozen_string_literal: true

class OverdueReminderWorker
  include Sidekiq::Job
  include TenantWorker

  sidekiq_options queue: :default, retry: 5

  BATCH_SIZE = 500

  def perform
    today = Date.current
    overdue_date = today - Rails.configuration.x.expense_overdue_days.days

    Company.find_each do |company|
      begin
        with_tenant(company.id) do
          reminder_rows = []

          Expense.pending
                 .where("incurred_on < ?", overdue_date)
                 .find_each(batch_size: BATCH_SIZE) do |expense|
            reminder_rows << {
              expense_id: expense.id,
              reminder_date: today,
              created_at: Time.current
            }

            if reminder_rows.size >= BATCH_SIZE
              insert_reminders(reminder_rows)
              reminder_rows.clear
            end
          end

          insert_reminders(reminder_rows) if reminder_rows.any?
        end
      rescue StandardError => error
        Rails.logger.error(
          "OverdueReminderWorker failed for company #{company.id}: #{error.class}: #{error.message}"
        )
      end
    end
  end

  private

  def insert_reminders(rows)
    OverdueReminder.upsert_all(
      rows,
      unique_by: :index_overdue_reminders_on_expense_id,
      update_only: %i[reminder_date created_at]
    )
  end
end
