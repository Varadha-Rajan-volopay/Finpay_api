require "rails_helper"

RSpec.describe "Sensitive data", type: :model do
  describe "Expense notes encryption" do
    it "stores notes encrypted in the database" do
      expense = create(:expense, notes: "Confidential expense note")

      stored_notes = Expense.connection.select_value(
        "SELECT notes FROM expenses WHERE id = #{expense.id}"
      )

      expect(stored_notes).not_to include("Confidential expense note")
      expect(expense.reload.notes).to eq("Confidential expense note")
    end
  end

  describe "Receipt OCR text encryption" do
    it "stores OCR text encrypted in the database" do
      receipt = create(:receipt, ocr_text: "Confidential OCR text")

      stored_ocr_text = Receipt.connection.select_value(
        "SELECT ocr_text FROM receipts WHERE id = #{receipt.id}"
      )

      expect(stored_ocr_text).not_to include("Confidential OCR text")
      expect(receipt.reload.ocr_text).to eq("Confidential OCR text")
    end
  end

  describe "parameter filtering" do
    it "filters notes and OCR text" do
      filter = ActiveSupport::ParameterFilter.new(
        Rails.application.config.filter_parameters
      )

      filtered = filter.filter(
        notes: "Confidential note",
        ocr_text: "Confidential OCR text"
      )

      expect(filtered[:notes]).to eq("[FILTERED]")
      expect(filtered[:ocr_text]).to eq("[FILTERED]")
    end
  end
end
