
# frozen_string_literal: true

module Api
  module V1
    class ExpensesController < ApplicationController
      after_action :verify_authorized, except: :index
      after_action :verify_policy_scoped, only: :index

      before_action :set_expense,
                    only: %i[
                      show
                      update
                      destroy
                      approve
                      reject
                      reimburse
                      archive
                    ]

      def index
        scope = policy_scope(Expense).includes(:category)

        filtered_scope = ExpenseFilter.new(
          scope,
          filter_params
        ).call

        result = ExpensePagination.new(
          filtered_scope,
          params
        ).call

        render_success(
          data: result[:data],
          meta: result[:meta]
        )
      rescue ExpenseFilter::InvalidFilter => e
        render_error(
          code: "invalid_filter",
          message: e.message,
          status: :unprocessable_entity
        )
      end

      def show
        authorize @expense

        render_success(
          data: serialized_expense(@expense)
        )
      end

      def create
        @expense = current_user.expenses.new(expense_params)

        authorize @expense

        result = ExpenseCrudService.call(
          expense: @expense,
          action: :create
        )

        if result.success?
          render_success(
            data: serialized_expense(result.value),
            status: :created
          )
        else
          render_error(
            code: "validation_failed",
            message: "Expense could not be created",
            details: result.errors
          )
        end
      end

      def update
        authorize @expense

        result = ExpenseCrudService.call(
          expense: @expense,
          action: :update,
          attributes: expense_params
        )

        if result.success?
          render_success(
            data: serialized_expense(result.value)
          )
        else
          render_error(
            code: "validation_failed",
            message: "Expense could not be updated",
            details: result.errors
          )
        end
      end

      def destroy
        authorize @expense

        result = ExpenseCrudService.call(
          expense: @expense,
          action: :destroy
        )

        if result.success?
          head :no_content
        else
          render_error(
            code: "deletion_failed",
            message: "Expense could not be deleted",
            details: result.errors
          )
        end
      end

      def approve
        perform_idempotent_workflow_action(:approve)
      end

      def reject
        perform_idempotent_workflow_action(:reject)
      end

      def reimburse
        authorize @expense

        idempotency_key = request.headers["Idempotency-Key"]

        if idempotency_key.present? && idempotency_key.length > 255
          return render json: {
            errors: [ "Idempotency-Key must not exceed 255 characters" ]
          }, status: :bad_request
        end

        result = ReimbursementIdempotencyService.call(
          expense: @expense,
          actor: current_user,
          idempotency_key: idempotency_key
        )

        response_body = result.value[:body]
        response_status = result.value[:status]

        if response_status == 200
          render_success(data: response_body)
        else
          errors = response_body[:errors] || response_body["errors"] || []

          render_error(
            code: "reimbursement_failed",
            message: errors.first || "Reimbursement could not be completed",
            details: errors,
            status: response_status
          )
        end
      end

      def archive
        perform_workflow_action(:archive)
      end

      private

      def set_expense
        @expense = policy_scope(Expense).find(params[:id])
      end

      def expense_params
        params.require(:expense).permit(
          :title,
          :category_id,
          :amount_cents,
          :currency,
          :incurred_on,
          :notes
        )
      end

      def filter_params
        params.except(
          :controller,
          :action,
          :page,
          :per,
          :pagination,
          :cursor
        )
      end

      def serialized_expense(expense)
        Api::V1::ExpenseSerializer.new(expense).serializable_hash
      end
      def perform_idempotent_workflow_action(action)
        authorize @expense

        result = ExpenseWorkflowIdempotencyService.call(
          expense: @expense,
          actor: current_user,
          action: action,
          idempotency_key: request.headers["Idempotency-Key"]
        )

        if result.success?
          render json: result.value[:body],
                status: result.value[:status]
        else
          render json: {
            errors: result.errors
          }, status: :unprocessable_entity
        end
      end

      def perform_workflow_action(action)
        authorize @expense

        result = ExpenseWorkflowService.call(
          expense: @expense,
          actor: current_user,
          action: action
        )

        if result.success?
          render_success(
            data: serialized_expense(result.value)
          )
        else
          render_error(
            code: "workflow_failed",
            message: "The expense workflow action could not be performed",
            details: result.errors
          )
        end
      end
    end
  end
end
