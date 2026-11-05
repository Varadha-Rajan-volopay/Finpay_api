
# frozen_string_literal: true

class Expense < ApplicationRecord
  include AASM

  before_validation :assign_reference_number, on: :create
  after_create_commit :enqueue_creation_audit

  belongs_to :user
  belongs_to :category

  before_destroy :prevent_deletion

  belongs_to :approved_by,
             class_name: "User",
             optional: true

  belongs_to :rejected_by,
             class_name: "User",
             optional: true

  belongs_to :reimbursed_by,
             class_name: "User",
             optional: true

  has_many :reimbursement_idempotency_records, dependent: :destroy
  has_many :receipts, dependent: :destroy
  has_many :overdue_reminders, dependent: :restrict_with_error
  has_many :activity_logs, dependent: :restrict_with_error

  aasm column: :status, create_scopes: false do
    state :pending, initial: true
    state :approved
    state :rejected
    state :reimbursed
    state :archived

    event :approve do
      transitions from: :pending, to: :approved
    end

    event :reject do
      transitions from: :pending, to: :rejected
    end

    event :reimburse do
      transitions from: :approved, to: :reimbursed
    end

    event :archive do
      transitions from: :reimbursed, to: :archived
    end
  end

  validates :status,
            inclusion: {
              in: %w[pending approved rejected reimbursed archived]
            }

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

  # Converts a user-entered decimal amount into integer minor units.
  # More than 2 decimal places are rejected, not rounded.
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

  # Converts calculated monetary amounts into minor units
  # using half-up rounding.
  def self.round_to_minor_units(amount, currency:)
    validate_currency!(currency)

    decimal_amount = begin
      BigDecimal(amount.to_s)
    rescue ArgumentError
      raise ArgumentError,
            "Amount must be a finite, non-negative decimal"
    end

    unless decimal_amount.finite? && decimal_amount >= 0
      raise ArgumentError,
            "Amount must be a finite, non-negative decimal"
    end

    (decimal_amount * 100).round(0, BigDecimal::ROUND_HALF_UP).to_i
  end

  def self.validate_currency!(currency)
    return if CURRENCIES.include?(currency)

    raise ArgumentError, "Unsupported currency"
  end

  private_class_method :validate_currency!

  private

  def assign_reference_number
    self.reference_number ||= "EXP-#{SecureRandom.hex(16).upcase}"
  end

  def enqueue_creation_audit
    AuditLogWorker.perform_async(
      user.company_id,
      id,
      user_id,
      "create",
      "new",
      status,
      created_at.iso8601(6)
    )
  rescue StandardError => error
    Rails.logger.error(
      "Failed to enqueue expense creation audit for expense #{id}: " \
      "#{error.class}: #{error.message}"
    )
  end

  def prevent_deletion
    errors.add(
      :base,
      "Expenses cannot be deleted because audit history must be preserved"
    )
    throw(:abort)
  end
end
