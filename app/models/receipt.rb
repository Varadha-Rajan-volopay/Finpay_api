class Receipt < ApplicationRecord
  belongs_to :expense

  encrypts :ocr_text

  after_create_commit :enqueue_ocr_processing

  validates :file_name, presence: true
  validates :content_type, presence: true
  validates :byte_size, presence: true,
                        numericality: { only_integer: true, greater_than: 0 }
  validates :storage_key, presence: true
  validates :ocr_status, presence: true

  private

  def enqueue_ocr_processing
    ReceiptProcessorWorker.perform_async(
      expense.user.company_id,
      id
    )
  end
end
