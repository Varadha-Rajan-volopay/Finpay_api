# frozen_string_literal: true

class ReimbursementIdempotencyService < ApplicationService
  def initialize(expense:, actor:, idempotency_key:)
    @expense = expense
    @actor = actor
    @idempotency_key = idempotency_key
  end

  def call
    return missing_key_result if @idempotency_key.blank?

    begin
      process_reimbursement
    rescue ActiveRecord::RecordNotUnique
      # Another concurrent request may have inserted this key.
      # The winning transaction has committed before this lookup succeeds.
      existing_record = ReimbursementIdempotencyRecord.find_by!(
        idempotency_key: @idempotency_key
      )

      response_for(existing_record)
    end
  end

  private

  def process_reimbursement
    response = nil

    Expense.transaction do
      @expense.with_lock do
        existing_record = ReimbursementIdempotencyRecord.find_by(
          idempotency_key: @idempotency_key
        )

        if existing_record
          response = response_for(existing_record)
          next
        end

        workflow_result = ExpenseWorkflowService.call(
          expense: @expense,
          actor: @actor,
          action: :reimburse
        )

        if workflow_result.success?
          response_body = ExpenseSerializer.new(
            @expense
          ).serializable_hash

          response_status = :ok
        else
          response_body = {
            errors: workflow_result.errors
          }

          response_status = :unprocessable_entity
        end

        record = ReimbursementIdempotencyRecord.create!(
          idempotency_key: @idempotency_key,
          expense: @expense,
          response_body: response_body,
          response_status: Rack::Utils.status_code(response_status)
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

  def response_for(record)
    if record.expense_id != @expense.id
      raise Errors::IdempotencyConflict,
            "Idempotency-Key has already been used for another expense"
    end

    {
      body: record.response_body,
      status: record.response_status,
      replayed: true
    }
  end

  def missing_key_result
    {
      body: {
        errors: [ "Idempotency-Key header is required" ]
      },
      status: :bad_request,
      replayed: false
    }
  end
end
