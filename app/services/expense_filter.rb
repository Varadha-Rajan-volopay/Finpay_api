class ExpenseFilter
  class InvalidFilter < StandardError
  end

  ALLOWED_FILTERS = %i[
    category_id
    status
    from
    to
  ].freeze

  def initialize(scope, params)
    @scope = scope
    @params = params
  end

  def call
    validate_filters!

    filtered_scope = @scope

    filtered_scope = filter_by_category(filtered_scope)
    filtered_scope = filter_by_status(filtered_scope)
    filtered_scope = filter_by_date_range(filtered_scope)

    filtered_scope
  end

  private

  def validate_filters!
    unknown_filters = @params.keys.map(&:to_sym) - ALLOWED_FILTERS

    if unknown_filters.any?
      raise InvalidFilter, "Unknown filters: #{unknown_filters.join(', ')}"
    end

    validate_status!
    validate_dates!
  end

  def filter_by_category(scope)
    return scope unless @params[:category_id].present?

    category_id = @params[:category_id]

    unless category_id.to_s.match?(/\A\d+\z/) && category_id.to_i.positive?
      raise InvalidFilter, "Invalid category_id"
    end

    scope.where(category_id: category_id.to_i)
  end

  def filter_by_status(scope)
    return scope unless @params[:status].present?

    scope.where(status: @params[:status])
  end

  def filter_by_date_range(scope)
    from_date = parse_date(@params[:from]) if @params[:from].present?
    to_date = parse_date(@params[:to]) if @params[:to].present?

    if from_date && to_date && from_date > to_date
      raise InvalidFilter, "'from' date cannot be after 'to' date"
    end

    scope = scope.where("incurred_on >= ?", from_date) if from_date
    scope = scope.where("incurred_on <= ?", to_date) if to_date

    scope
  end

  def validate_status!
    return unless @params[:status].present?

    allowed_statuses = Expense.statuses.keys

    unless allowed_statuses.include?(@params[:status].to_s)
      raise InvalidFilter, "Invalid status"
    end
  end

  def validate_dates!
    parse_date(@params[:from]) if @params[:from].present?
    parse_date(@params[:to]) if @params[:to].present?
  end

  def parse_date(value)
    unless value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      raise InvalidFilter, "Invalid date format. Use YYYY-MM-DD"
    end

    Date.iso8601(value)
  rescue ArgumentError
    raise InvalidFilter, "Invalid date"
  end
end
