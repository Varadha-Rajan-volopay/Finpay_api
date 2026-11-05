class AddReceiptExpenseForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :receipts, :expenses, validate: false
  end
end
