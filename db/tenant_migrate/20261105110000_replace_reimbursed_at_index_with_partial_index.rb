# frozen_string_literal: true

class ReplaceReimbursedAtIndexWithPartialIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  OLD_INDEX_NAME = "index_expenses_on_reimbursed_at"
  NEW_INDEX_NAME = "index_expenses_on_reimbursed_at_not_null"

  def up
    unless index_valid?(NEW_INDEX_NAME)
      if index_exists?(:expenses, name: NEW_INDEX_NAME)
        remove_index :expenses,
                     name: NEW_INDEX_NAME,
                     algorithm: :concurrently
      end

      add_index :expenses,
                :reimbursed_at,
                name: NEW_INDEX_NAME,
                where: "reimbursed_at IS NOT NULL",
                algorithm: :concurrently
    end

    if index_exists?(:expenses, name: OLD_INDEX_NAME)
      remove_index :expenses,
                   name: OLD_INDEX_NAME,
                   algorithm: :concurrently
    end
  end

  def down
    unless index_valid?(OLD_INDEX_NAME)
      if index_exists?(:expenses, name: OLD_INDEX_NAME)
        remove_index :expenses,
                     name: OLD_INDEX_NAME,
                     algorithm: :concurrently
      end

      add_index :expenses,
                :reimbursed_at,
                name: OLD_INDEX_NAME,
                algorithm: :concurrently
    end

    if index_exists?(:expenses, name: NEW_INDEX_NAME)
      remove_index :expenses,
                   name: NEW_INDEX_NAME,
                   algorithm: :concurrently
    end
  end

  private

  def index_valid?(index_name)
    result = select_one(<<~SQL)
      SELECT i.indisvalid, i.indisunique
      FROM pg_class c
      JOIN pg_index i ON i.indexrelid = c.oid
      WHERE c.relname = #{connection.quote(index_name)}
        AND pg_table_is_visible(c.oid)
    SQL

    result.present? &&
      ActiveModel::Type::Boolean.new.cast(result["indisvalid"])
  end
end
