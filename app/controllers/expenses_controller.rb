class ExpensesController < ApplicationController
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  before_action :set_expense, only: %i[show update destroy]

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
end
