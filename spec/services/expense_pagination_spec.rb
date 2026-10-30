require "rails_helper"

RSpec.describe ExpensePagination do
  let(:user) { create(:user) }
  let(:category) { create(:category) }

  let!(:first_expense) do
    create(
      :expense,
      user: user,
      category: category,
      created_at: Time.zone.parse("2026-10-30 10:00:00"),
      updated_at: Time.zone.parse("2026-10-30 10:00:00")
    )
  end

  let!(:second_expense) do
    create(
      :expense,
      user: user,
      category: category,
      created_at: Time.zone.parse("2026-10-30 11:00:00"),
      updated_at: Time.zone.parse("2026-10-30 11:00:00")
    )
  end

  let!(:third_expense) do
    create(
      :expense,
      user: user,
      category: category,
      created_at: Time.zone.parse("2026-10-30 12:00:00"),
      updated_at: Time.zone.parse("2026-10-30 12:00:00")
    )
  end

  let(:scope) { Expense.where(user_id: user.id) }

  def serialized_data(result)
    JSON.parse(result[:data])
  end

  describe "#call" do
    context "with offset pagination" do
      it "returns the requested page" do
        result = described_class.new(
          scope,
          { page: 2, per: 2 }
        ).call

        data = serialized_data(result)

        expect(data.length).to eq(1)
        expect(data.first["id"]).to eq(first_expense.id)
      end

      it "returns pagination metadata" do
        result = described_class.new(
          scope,
          { page: 1, per: 2 }
        ).call

        expect(result[:meta]).to include(
          page: 1,
          total_pages: 2
        )
      end

      it "uses the default page size when per is not provided" do
        result = described_class.new(
          scope,
          { page: 1 }
        ).call

        data = serialized_data(result)

        expect(data.length).to eq(3)
        expect(result[:meta][:page]).to eq(1)
      end

      it "caps per at the maximum allowed value" do
        create_list(
          :expense,
          101,
          user: user,
          category: category
        )

        result = described_class.new(
          scope,
          { page: 1, per: 500 }
        ).call

        data = serialized_data(result)

        expect(data.length).to eq(100)
        expect(result[:meta][:total_pages]).to eq(2)
      end

      it "rejects a non-positive per value" do
        expect do
          described_class.new(
            scope,
            { per: 0 }
          ).call
        end.to raise_error(
          ActionController::BadRequest,
          "Invalid per value"
        )
      end

      it "rejects an invalid per value" do
        expect do
          described_class.new(
            scope,
            { per: "invalid" }
          ).call
        end.to raise_error(
          ActionController::BadRequest,
          "Invalid per value"
        )
      end
    end

    context "with keyset pagination" do
      it "returns the first page and a next cursor" do
        result = described_class.new(
          scope,
          { pagination: "keyset", per: 2 }
        ).call

        data = serialized_data(result)

        expect(data.length).to eq(2)
        expect(result[:meta][:has_next]).to be(true)
        expect(result[:meta][:next_cursor]).to be_present
      end

      it "returns the next page using the cursor" do
        first_page = described_class.new(
          scope,
          { pagination: "keyset", per: 2 }
        ).call

        second_page = described_class.new(
          scope,
          {
            pagination: "keyset",
            per: 2,
            cursor: first_page[:meta][:next_cursor]
          }
        ).call

        data = serialized_data(second_page)

        expect(data.length).to eq(1)
        expect(data.first["id"]).to eq(first_expense.id)
        expect(second_page[:meta][:has_next]).to be(false)
        expect(second_page[:meta][:next_cursor]).to be_nil
      end

      it "rejects an invalid cursor" do
        expect do
          described_class.new(
            scope,
            {
              pagination: "keyset",
              per: 2,
              cursor: "invalid-cursor"
            }
          ).call
        end.to raise_error(
          ActionController::BadRequest,
          "invalid cursor"
        )
      end
    end
  end
end
