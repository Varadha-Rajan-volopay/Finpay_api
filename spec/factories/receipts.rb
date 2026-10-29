FactoryBot.define do
  factory :receipt do
    association :expense

    file_name { "receipt.pdf" }
    content_type { "application/pdf" }
    byte_size { 1024 }
    storage_key { "receipts/test-receipt.pdf" }
    ocr_status { "pending" }
    ocr_text { "Sensitive OCR content" }
  end
end
