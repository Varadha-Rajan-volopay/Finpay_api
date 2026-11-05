# frozen_string_literal: true

class OverdueReminder < ApplicationRecord
  belongs_to :expense

  validates :reminder_date, presence: true
end
