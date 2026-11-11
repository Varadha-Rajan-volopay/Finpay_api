# frozen_string_literal: true

class ReceiptProcessorWorker
  include Sidekiq::Job
  include TenantWorker

  sidekiq_options queue: :default, retry: 5

  sidekiq_retries_exhausted do |job, exception|
    tenant_id, receipt_id = job["args"]

    Rails.logger.error(
      "Receipt OCR retries exhausted for receipt #{receipt_id}: #{exception.message}"
    )

    ReceiptProcessorWorker.mark_failed(tenant_id, receipt_id)
  end

  def perform(tenant_id, receipt_id)
    with_tenant(tenant_id) do
      receipt = Receipt.find_by(id: receipt_id)

      unless receipt
        Rails.logger.warn(
          "ReceiptProcessorWorker: Receipt not found for receipt_id=#{receipt_id}; skipping job"
        )
        next
      end

      next if receipt.ocr_status == "done"


      receipt.update!(ocr_status: "processing")


      fake_ocr_text = "Fake OCR output for #{receipt.file_name}"


      receipt.with_lock do
        next if receipt.ocr_status == "done"

        receipt.update!(
          ocr_text: fake_ocr_text,
          ocr_status: "done"
        )
      end
    end
  end

  def self.mark_failed(tenant_id, receipt_id)
    worker = new

    worker.send(:with_tenant, tenant_id) do
      receipt = Receipt.find_by(id: receipt_id)

      if receipt && receipt.ocr_status != "done"
        receipt.update!(ocr_status: "failed")
      end
    end
  rescue StandardError => error
    Rails.logger.error(
      "Failed to mark receipt #{receipt_id} as failed: #{error.message}"
    )
  end
end
