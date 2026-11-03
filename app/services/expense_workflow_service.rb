
class ExpenseWorkflowService < ApplicationService
  ACTIONS = %i[
    approve
    reject
    reimburse
    archive
  ].freeze

  def initialize(expense:, actor:, action:)
    @expense = expense
    @actor = actor
    @action = action.to_sym
  end

  def call
    unless ACTIONS.include?(@action)
      return Result.new(
        success: false,
        errors: [ "Invalid workflow action: #{@action}" ]
      )
    end

    result = nil

    Expense.transaction do
      @expense.with_lock do
        from_state = @expense.status

        unless @expense.public_send("may_#{@action}?")
          result = Result.new(
            success: false,
            errors: [
              "Cannot #{@action} an expense from #{from_state} status"
            ]
          )

          next
        end

        @expense.public_send("#{@action}!")

        to_state = @expense.status

        ActivityLog.create!(
          expense: @expense,
          actor: @actor,
          action: @action.to_s,
          from_state: from_state,
          to_state: to_state
        )

        ActiveRecord.after_all_transactions_commit do
          AuditLogWorker.perform_async(
            @expense.user.company_id,
            @expense.id,
            @actor.id,
            @action.to_s,
            from_state,
            to_state
          )
        end

        result = Result.new(
          success: true,
          value: @expense
        )
      end
    end

    result
  end
end
