# frozen_string_literal: true

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
             :reference_number,
             :reimbursed_at,
             :created_at,
             :updated_at

  attribute :amount_display do |expense|
    whole_units, minor_units = expense.amount_cents.divmod(100)

    "#{whole_units}.#{minor_units.to_s.rjust(2, '0')}"
  end

  attribute :category_name do |expense|
    expense.category.name
  end
end
