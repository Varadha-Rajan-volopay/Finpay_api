class UpdateExpensesForCoreExpenseTracking < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    if table_exists?(:expenses)
      update_existing_expenses_table
    else
      create_expenses_table
    end

    add_index :expenses, :user_id, algorithm: :concurrently
    add_index :expenses, :category_id, algorithm: :concurrently
    add_index :expenses, :status, algorithm: :concurrently
    add_index :expenses, :incurred_on, algorithm: :concurrently
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Expense schema changes require a deliberate rollback."
  end

  private

  def update_existing_expenses_table
    # The existing public expenses table was checked and is empty.
    safety_assured do
      remove_column :expenses, :description
      remove_column :expenses, :amount
    end

    add_column :expenses, :user_id, :bigint, null: false
    add_column :expenses, :category_id, :bigint, null: false
    add_column :expenses, :title, :string, null: false
    add_column :expenses, :amount_cents, :bigint, null: false
    add_column :expenses, :currency, :string, limit: 3, null: false
    add_column :expenses, :status, :string, null: false, default: "pending"
    add_column :expenses, :incurred_on, :date, null: false
    add_column :expenses, :notes, :text
  end

  def create_expenses_table
    create_table :expenses do |t|
      t.bigint :user_id, null: false
      t.bigint :category_id, null: false
      t.string :title, null: false
      t.bigint :amount_cents, null: false
      t.string :currency, limit: 3, null: false
      t.string :status, null: false, default: "pending"
      t.date :incurred_on, null: false
      t.text :notes

      t.timestamps
    end
  end
end
