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

    Expense.transaction(requires_new: true) do
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

        case @action
        when :approve
          @expense.update!(
            approved_by: @actor,
            approved_at: Time.current
          )
        when :reject
          @expense.update!(
            rejected_by: @actor,
            rejected_at: Time.current
          )
        when :reimburse
          @expense.update!(
            reimbursed_by: @actor,
            reimbursed_at: Time.current
          )
        end

        to_state = @expense.status

        ActivityLog.create!(
          expense: @expense,
          actor: @actor,
          action: @action.to_s,
          from_state: from_state,
          to_state: to_state
        )


        result = Result.new(
          success: true,
          value: @expense
        )
      end
    end

    result
  end
end
