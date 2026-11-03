class ExpensePagination
  DEFAULT_PER = 20
  MAX_PER = 100

  def initialize(scope, params)
    @scope = scope
    @params = params
  end

  def call
    per = pagination_per

    if @params[:pagination] == "keyset"
      keyset_pagination(per)
    else
      offset_pagination(per)
    end
  end

  private

  def pagination_per
    value = @params[:per].presence || DEFAULT_PER
    per = Integer(value.to_s, 10)

    raise ActionController::BadRequest, "Invalid per value" unless per.positive?

    [ per, MAX_PER ].min
  rescue ArgumentError, TypeError
    raise ActionController::BadRequest, "Invalid per value"
  end

  def offset_pagination(per)
    expenses = @scope
      .order(created_at: :desc, id: :desc)
      .page(@params[:page])
      .per(per)

    {
      data: ExpenseSerializer.new(expenses).serialize,
      meta: {
        page: expenses.current_page,
        total_pages: expenses.total_pages
      }
    }
  end

  def keyset_pagination(per)
    scope = @scope.order(created_at: :desc, id: :desc)

    if @params[:cursor].present?
      cursor = Cursor.decode(@params[:cursor])

      scope = scope.where(
        "(created_at, id) < (?, ?)",
        cursor[:created_at],
        cursor[:id]
      )
    end

    records = scope.limit(per + 1).to_a

    has_next = records.size > per
    expenses = records.first(per)

    {
      data: ExpenseSerializer.new(expenses).serialize,
      meta: {
        per: per,
        has_next: has_next,
        next_cursor: has_next ? Cursor.encode(expenses.last) : nil
      }
    }
  end
end
