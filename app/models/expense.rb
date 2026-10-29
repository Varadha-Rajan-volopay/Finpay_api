class Expense < ApplicationRecord
  belongs_to :user
  belongs_to :category

  has_many :receipts, dependent: :destroy

  enum :status, {
    pending: "pending",
    approved: "approved",
    rejected: "rejected",
    reimbursed: "reimbursed",
    archived: "archived"
  }, validate: true

  CURRENCIES = %w[INR USD EUR].freeze

  encrypts :notes

  validates :title, presence: true

  validates :amount_cents,
            numericality: {
              only_integer: true,
              greater_than: 0
            }

  validates :currency,
            inclusion: { in: CURRENCIES }

  validates :incurred_on, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :for_month, ->(date) { where(incurred_on: date.all_month) }

  delegate :name, to: :category, prefix: true

  def amount_display
    whole_units, minor_units = amount_cents.divmod(100)

    "#{whole_units}.#{minor_units.to_s.rjust(2, '0')}"
  end
  def self.amount_cents_from(amount, currency:)
    unless CURRENCIES.include?(currency)
      raise ArgumentError, "Unsupported currency"
    end

    amount_string = amount.to_s

    unless amount_string.match?(/\A\d+(?:\.\d+)?\z/)
      raise ArgumentError, "Amount must be a non-negative decimal"
    end

    decimal_places = amount_string.split(".", 2).last&.length || 0

    if decimal_places > 2
      raise ArgumentError, "Amount has too many decimal places for #{currency}"
    end

    (BigDecimal(amount_string) * 100).to_i
  end
end
