require "rails_helper"

RSpec.describe ExpenseCrudService do
  describe "#call" do
    let(:expense) { double("Expense", reference_number: "EXP-ORIGINAL") }

    it "retries when the reference number unique index causes a conflict" do
      error = ActiveRecord::RecordNotUnique.new(
        "duplicate key violates index #{described_class::REFERENCE_NUMBER_INDEX}"
      )

      expect(expense).to receive(:save!).ordered.and_raise(error)
      expect(expense).to receive(:reference_number=).with(nil).ordered
      expect(expense).to receive(:save!).ordered.and_return(true)

      result = described_class.new(
        expense: expense,
        action: :create
      ).call

      expect(result.success?).to be(true)
      expect(result.value).to eq(expense)
    end

    it "does not retry unrelated unique constraint violations" do
      error = ActiveRecord::RecordNotUnique.new(
        "duplicate key violates another_unique_index"
      )

      expect(expense).to receive(:save!).once.and_raise(error)
      expect(expense).not_to receive(:reference_number=)

      expect do
        described_class.new(
          expense: expense,
          action: :create
        ).call
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "stops after the maximum number of reference number attempts" do
      error = ActiveRecord::RecordNotUnique.new(
        "duplicate key violates index #{described_class::REFERENCE_NUMBER_INDEX}"
      )

      expect(expense).to receive(:save!).exactly(3).times.and_raise(error)
      expect(expense).to receive(:reference_number=).with(nil).twice

      expect do
        described_class.new(
          expense: expense,
          action: :create
        ).call
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
