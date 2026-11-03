# frozen_string_literal: true

class OverdueReminderWorker
  include Sidekiq::Job
  include TenantWorker

  sidekiq_options queue: :default, retry: 5

  def perform
    Company.find_each do |company|
      with_tenant(company.id) do
        overdue_date = Date.current - Rails.configuration.x.expense_overdue_days.days

        Expense.pending
               .where("incurred_on < ?", overdue_date)
               .find_each do |expense|
          OverdueReminder.create_or_find_by!(
            expense_id: expense.id,
            reminder_date: Date.current
          )
        end
      end
    end
  end
end
