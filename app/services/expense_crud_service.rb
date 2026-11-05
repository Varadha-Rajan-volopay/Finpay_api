
# frozen_string_literal: true

class ExpenseCrudService < ApplicationService
  ACTIONS = %i[create update destroy].freeze
  REFERENCE_NUMBER_INDEX = "index_expenses_on_reference_number_unique"
  MAX_REFERENCE_NUMBER_ATTEMPTS = 3

  def initialize(expense:, action:, attributes: {})
    @expense = expense
    @action = action.to_sym
    @attributes = attributes
  end

  def call
    unless ACTIONS.include?(@action)
      return Result.new(
        success: false,
        errors: [ "Invalid expense action" ]
      )
    end

    case @action
    when :create
      create_expense
    when :update
      update_expense
    when :destroy
      destroy_expense
    end
  rescue ActiveRecord::RecordInvalid => error
    Result.new(
      success: false,
      value: @expense,
      errors: error.record.errors.full_messages
    )
  rescue ActiveRecord::RecordNotDestroyed => error
    Result.new(
      success: false,
      value: @expense,
      errors: error.record.errors.full_messages
    )
  end

  private

  def create_expense
    attempts = 0

    begin
      @expense.save!
    rescue ActiveRecord::RecordNotUnique => error
      raise unless error.message.include?(REFERENCE_NUMBER_INDEX)

      attempts += 1
      raise if attempts >= MAX_REFERENCE_NUMBER_ATTEMPTS

      @expense.reference_number = nil
      retry
    end

    Result.new(success: true, value: @expense)
  end

  def update_expense
    @expense.update!(@attributes)

    Result.new(success: true, value: @expense)
  end

  def destroy_expense
    @expense.destroy!

    Result.new(success: true, value: @expense)
  end
end
