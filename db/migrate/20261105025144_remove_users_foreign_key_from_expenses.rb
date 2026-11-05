class RemoveUsersForeignKeyFromExpenses < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :expenses, :users
  end

  def down
    add_foreign_key :expenses, :users, validate: false
  end
end
