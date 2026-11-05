# frozen_string_literal: true

class AddReferenceNumberToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :reference_number, :string
  end
end
