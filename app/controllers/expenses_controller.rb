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

    render json: result, status: :ok
  rescue ExpenseFilter::InvalidFilter => e
    render json: { error: e.message },
           status: :unprocessable_entity
  end

  def show
    authorize @expense

    render json: ExpenseSerializer.new(@expense).serialize,
           status: :ok
  end

  def create
    @expense = current_user.expenses.new(expense_params)
    @expense.status = "pending"

    authorize @expense

    if @expense.save
      render json: ExpenseSerializer.new(@expense).serialize,
             status: :created
    else
      render json: {
        errors: @expense.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    authorize @expense

    if @expense.update(expense_params)
      render json: ExpenseSerializer.new(@expense).serialize,
             status: :ok
    else
      render json: {
        errors: @expense.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @expense

    if @expense.destroy
      head :no_content
    else
      render json: {
        errors: @expense.errors.full_messages
      }, status: :unprocessable_entity
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

    if result.failure?
      return render json: {
        errors: result.errors
      }, status: :unprocessable_entity
    end

    render json: result.value[:body],
           status: result.value[:status]
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
      render json: ExpenseSerializer.new(@expense).serialize,
            status: :ok
    else
      render json: {
        errors: result.errors
      }, status: :unprocessable_entity
    end
  end
end
