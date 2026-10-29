class ValidateReceiptExpenseForeignKey < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :receipts, :expenses
  end
end
