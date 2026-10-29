class CreateExpenseTrackingTenantTables < ActiveRecord::Migration[8.1]
  def up
    create_categories_table
    create_expenses_table
    create_receipts_table

    add_expense_indexes
    add_expense_foreign_keys
    add_expense_constraints
    add_receipt_indexes
    add_receipt_foreign_keys
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Expense-tracking tenant tables require a deliberate rollback."
  end

  private

  def create_categories_table
    return if table_exists?(:categories)

    create_table :categories do |t|
      t.string :name, null: false
      t.timestamps
    end
  end

  def create_expenses_table
    return if table_exists?(:expenses)

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

  def create_receipts_table
    return if table_exists?(:receipts)

    create_table :receipts do |t|
      t.bigint :expense_id, null: false
      t.string :file_name, null: false
      t.string :content_type, null: false
      t.bigint :byte_size, null: false
      t.string :storage_key, null: false
      t.string :ocr_status, null: false, default: "pending"
      t.text :ocr_text
      t.timestamps
    end
  end

  def add_expense_indexes
    add_index :categories, :name, unique: true unless index_exists?(:categories, :name, unique: true)

    add_index :expenses, :user_id unless index_exists?(:expenses, :user_id)
    add_index :expenses, :category_id unless index_exists?(:expenses, :category_id)
    add_index :expenses, :status unless index_exists?(:expenses, :status)
    add_index :expenses, :incurred_on unless index_exists?(:expenses, :incurred_on)
  end

  def add_expense_foreign_keys
    unless foreign_key_exists?(:expenses, :users)
      add_foreign_key :expenses, :users, validate: false
    end

    unless foreign_key_exists?(:expenses, :categories)
      add_foreign_key :expenses, :categories, validate: false
    end
  end

  def add_expense_constraints
    unless check_constraint_exists?(:expenses, name: "chk_expenses_amount_cents_positive")
      add_check_constraint(
        :expenses,
        "amount_cents > 0",
        name: "chk_expenses_amount_cents_positive"
      )
    end

    unless check_constraint_exists?(:expenses, name: "chk_expenses_currency_format")
      add_check_constraint(
        :expenses,
        "currency ~ '^[A-Z]{3}$'",
        name: "chk_expenses_currency_format"
      )
    end
  end

  def add_receipt_indexes
    add_index :receipts, :expense_id unless index_exists?(:receipts, :expense_id)
  end

  def add_receipt_foreign_keys
    unless foreign_key_exists?(:receipts, :expenses)
      add_foreign_key :receipts, :expenses, validate: false
    end
  end
end
