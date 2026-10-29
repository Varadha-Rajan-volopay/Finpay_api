class CreateReceipts < ActiveRecord::Migration[8.1]
  def change
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

    add_index :receipts, :expense_id
  end
end
