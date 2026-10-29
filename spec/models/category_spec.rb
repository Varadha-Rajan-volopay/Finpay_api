require "rails_helper"

RSpec.describe Category, type: :model do
  describe "validations" do
    subject(:category) { build(:category) }

    it "requires a name" do
      category.name = nil

      expect(category).not_to be_valid
      expect(category.errors[:name]).to include("can't be blank")
    end

    it "requires a unique name" do
      existing_category = create(:category, name: "Travel")
      duplicate_category = build(:category, name: existing_category.name)

      expect(duplicate_category).not_to be_valid
      expect(duplicate_category.errors[:name]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "has many expenses with restrict_with_error" do
      association = described_class.reflect_on_association(:expenses)

      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:restrict_with_error)
    end
  end
end
