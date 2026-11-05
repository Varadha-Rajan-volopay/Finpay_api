
# frozen_string_literal: true

class ReimbursementIdempotencyService < ApplicationService
  def initialize(expense:, actor:, idempotency_key:)
    @expense = expense
    @actor = actor
    @idempotency_key = idempotency_key
  end

  def call
    return missing_key_result if @idempotency_key.blank?

    process_reimbursement
  rescue ActiveRecord::RecordNotUnique
    existing_record = ReimbursementIdempotencyRecord.find_by(
      actor_id: @actor.id,
      idempotency_key: @idempotency_key
    )

    raise unless existing_record

    response_for(existing_record)
  end

  private

  def process_reimbursement
    response = nil

    Expense.transaction do
      @expense.with_lock do
        existing_record = ReimbursementIdempotencyRecord.find_by(
          actor_id: @actor.id,
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

        unless workflow_result.success?
          response = {
            body: { errors: workflow_result.errors },
            status: :unprocessable_entity,
            replayed: false
          }

          next
        end

        response_body = ExpenseSerializer.new(
          @expense
        ).serializable_hash

        record = ReimbursementIdempotencyRecord.create!(
          actor: @actor,
          idempotency_key: @idempotency_key,
          expense: @expense,
          response_body: response_body,
          response_status: Rack::Utils.status_code(:ok)
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
