# frozen_string_literal: true

class ReceiptProcessorWorker
  include Sidekiq::Job
  include TenantWorker

  sidekiq_options queue: :default, retry: 5

  def perform(tenant_id, receipt_id)
    with_tenant(tenant_id) do
      receipt = Receipt.find(receipt_id)

      receipt.with_lock do
        next if receipt.ocr_status == "done"

        receipt.update!(ocr_status: "processing")

        fake_ocr_text = "Fake OCR output for #{receipt.file_name}"

        receipt.update!(
          ocr_text: fake_ocr_text,
          ocr_status: "done"
        )
      end
    end
  rescue StandardError => error
    mark_failed(tenant_id, receipt_id)
    raise error
  end

  private

  def mark_failed(tenant_id, receipt_id)
    with_tenant(tenant_id) do
      receipt = Receipt.find_by(id: receipt_id)

      if receipt && receipt.ocr_status != "done"
        receipt.update!(ocr_status: "failed")
      end
    end
  rescue StandardError
    # Preserve the original processing error.
  end
end
