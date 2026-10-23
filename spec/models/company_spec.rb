
require "rails_helper"

RSpec.describe Company, type: :model do
  describe "validations" do
    it "accepts a valid company" do
      company = Company.new(name: "Acme Corp", subdomain: "acme")

      expect(company).to be_valid
    end

    it "requires a name" do
      company = Company.new(name: nil, subdomain: "acme")

      expect(company).not_to be_valid
      expect(company.errors[:name]).to be_present
    end

    it "requires a subdomain" do
      company = Company.new(name: "Acme Corp", subdomain: nil)

      expect(company).not_to be_valid
      expect(company.errors[:subdomain]).to be_present
    end

    it "rejects an invalid subdomain format" do
      ["Acme", "ab", "1acme", "acme-name", "acme.example"].each do |subdomain|
        company = Company.new(name: "Acme Corp", subdomain: subdomain)

        expect(company).not_to be_valid, "Expected #{subdomain.inspect} to be invalid"
      end
    end

    it "rejects duplicate subdomains" do
      Company.create!(name: "First Company", subdomain: "acme")

      duplicate = Company.new(name: "Second Company", subdomain: "acme")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:subdomain]).to be_present
    end
  end
end
