class Receipt < ApplicationRecord
  belongs_to :expense

  encrypts :ocr_text

  validates :file_name, presence: true
  validates :content_type, presence: true
  validates :byte_size, presence: true,
                        numericality: { only_integer: true, greater_than: 0 }
  validates :storage_key, presence: true
  validates :ocr_status, presence: true
end
