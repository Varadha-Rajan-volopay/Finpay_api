
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

  # Returns the amount in major currency units as a decimal string.
  # Example: 1050 cents -> "10.50"
  def amount_display
    whole_units, minor_units = amount_cents.divmod(100)

    "#{whole_units}.#{minor_units.to_s.rjust(2, '0')}"
  end

  # Converts a user-entered decimal amount into integer minor units.
  # User input with more than 2 decimal places is rejected, not rounded.
  # Example: "10.50" INR -> 1050 cents
  def self.amount_cents_from(amount, currency:)
    validate_currency!(currency)

    amount_string = amount.to_s

    unless amount_string.match?(/\A\d+(?:\.\d+)?\z/)
      raise ArgumentError,
            "Amount must be a non-negative decimal with at most 2 decimal places"
    end

    decimal_places = amount_string.split(".", 2).last.length if amount_string.include?(".")

    if decimal_places && decimal_places > 2
      raise ArgumentError,
            "Amount has too many decimal places for #{currency}"
    end

    (BigDecimal(amount_string) * 100).to_i
  end

  # Converts a calculated monetary amount into integer minor units
  # using half-up rounding.
  #
  # Example:
  # "1.005" -> 101 cents
  # "1.004" -> 100 cents
  def self.round_to_minor_units(amount, currency:)
    validate_currency!(currency)

    decimal_amount = BigDecimal(amount.to_s)

    unless decimal_amount.finite? && decimal_amount >= 0
      raise ArgumentError,
            "Amount must be a finite, non-negative decimal"
    end

    (decimal_amount * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  rescue ArgumentError
    raise ArgumentError,
          "Amount must be a finite, non-negative decimal"
  end

  def self.validate_currency!(currency)
    return if CURRENCIES.include?(currency)

    raise ArgumentError, "Unsupported currency"
  end

  private_class_method :validate_currency!
end
