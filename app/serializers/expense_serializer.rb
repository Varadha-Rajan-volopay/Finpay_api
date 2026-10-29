class ExpenseSerializer
  include Alba::Resource

  attributes :id,
             :user_id,
             :category_id,
             :title,
             :amount_cents,
             :currency,
             :status,
             :incurred_on,
             :created_at,
             :updated_at

  attribute :amount_display do |expense|
    expense.amount_display
  end

  attribute :category_name do |expense|
    expense.category.name
  end
end
