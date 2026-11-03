# frozen_string_literal: true

class OverdueReminder < ApplicationRecord
  validates :expense_id, presence: true
  validates :reminder_date, presence: true
end
