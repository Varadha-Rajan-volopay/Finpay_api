# frozen_string_literal: true

class ExpenseWorkflowService < ApplicationService
  ACTIONS = %i[
    approve
    reject
    reimburse
    archive
  ].freeze

  TRACKING_COLUMNS = {
    approve: [ :approved_by_id, :approved_at ],
    reject: [ :rejected_by_id, :rejected_at ],
    reimburse: [ :reimbursed_by_id, :reimbursed_at ]
  }.freeze

  def initialize(expense:, actor:, action:)
    @expense = expense
    @actor = actor
    @action = action.to_sym
  end

  def call
    unless ACTIONS.include?(@action)
      raise Errors::InvalidTransition,
            "Invalid workflow action: #{@action}"
    end

    result = nil

    Expense.transaction do
      @expense.with_lock do
        from_state = @expense.status

        unless @expense.public_send("may_#{@action}?")
          raise Errors::InvalidTransition,
                "Cannot #{@action} an expense from #{from_state} status"
        end

        transition_time = Time.current

        @expense.public_send("#{@action}!")

        if (tracking_columns = TRACKING_COLUMNS[@action])
          actor_column, timestamp_column = tracking_columns

          @expense.update!(
            actor_column => @actor.id,
            timestamp_column => transition_time
          )
        end

        to_state = @expense.status

        activity_log = ActivityLog.create!(
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
            to_state,
            activity_log.created_at.iso8601(6)
          )
        end
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
