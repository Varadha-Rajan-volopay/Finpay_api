class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false

      t.timestamps
    end
  end
end