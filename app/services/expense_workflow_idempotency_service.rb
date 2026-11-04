
class ExpenseWorkflowIdempotencyService < ApplicationService
  ACTIONS = %i[approve reject].freeze

  def initialize(expense:, actor:, action:, idempotency_key:)
    @expense = expense
    @actor = actor
    @action = action.to_sym
    @idempotency_key = idempotency_key
  end

  def call
    return missing_key_result if @idempotency_key.blank?

    unless ACTIONS.include?(@action)
      return error_result("Invalid workflow action: #{@action}", :unprocessable_entity)
    end

    process_request
  rescue ActiveRecord::RecordNotUnique
    record = ReimbursementIdempotencyRecord.find_by!(
      idempotency_key: stored_key
    )

    response_for(record)
  end

  private

  def process_request
    response = nil

    Expense.transaction do
      @expense.with_lock do
        record = ReimbursementIdempotencyRecord.find_by(
          idempotency_key: stored_key
        )

        if record
          response = response_for(record)
          next
        end

        result = ExpenseWorkflowService.call(
          expense: @expense,
          actor: @actor,
          action: @action
        )

        if result.success?
          body = ExpenseSerializer.new(@expense.reload).serialize
          status = :ok
        else
          body = { errors: result.errors }
          status = :unprocessable_entity
        end

        record = ReimbursementIdempotencyRecord.create!(
          idempotency_key: stored_key,
          expense: @expense,
          response_body: body,
          response_status: Rack::Utils.status_code(status)
        )

        response = {
          body: record.response_body,
          status: record.response_status,
          replayed: false
        }
      end
    end

    response
  end

  def stored_key
    "#{@action}:#{@idempotency_key}"
  end

  def response_for(record)
    if record.expense_id != @expense.id
      error_result(
        "Idempotency-Key has already been used for another expense",
        :unprocessable_entity
      )
    else
      {
        body: record.response_body,
        status: record.response_status,
        replayed: true
      }
    end
  end

  def missing_key_result
    error_result("Idempotency-Key header is required", :bad_request)
  end

  def error_result(message, status)
    {
      body: { errors: [ message ] },
      status: status,
      replayed: false
    }
  end
end
