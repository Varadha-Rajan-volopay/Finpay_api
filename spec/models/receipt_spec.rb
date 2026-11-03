require "rails_helper"

RSpec.describe Receipt, type: :model do
  describe "validations" do
    subject(:receipt) { build(:receipt) }

    it "requires a file name" do
      receipt.file_name = nil

      expect(receipt).not_to be_valid
      expect(receipt.errors[:file_name]).to include("can't be blank")
    end

    it "requires a content type" do
      receipt.content_type = nil

      expect(receipt).not_to be_valid
      expect(receipt.errors[:content_type]).to include("can't be blank")
    end

    it "requires a positive integer byte size" do
      receipt.byte_size = 0

      expect(receipt).not_to be_valid
      expect(receipt.errors[:byte_size]).not_to be_empty
    end

    it "requires a storage key" do
      receipt.storage_key = nil

      expect(receipt).not_to be_valid
      expect(receipt.errors[:storage_key]).to include("can't be blank")
    end

    it "requires an OCR status" do
      receipt.ocr_status = nil

      expect(receipt).not_to be_valid
      expect(receipt.errors[:ocr_status]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "belongs to an expense" do
      association = described_class.reflect_on_association(:expense)

      expect(association.macro).to eq(:belongs_to)
    end
  end
end
