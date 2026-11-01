
require "rails_helper"

RSpec.describe Companies::Provision do
  describe ".call" do
    let(:name) { "Acme Corp" }
    let(:subdomain) { "acme" }
    let(:connection) { ActiveRecord::Base.connection }

    before do
        allow(connection).to receive(:schema_exists?).and_return(false)
    end

    it "creates a company and provisions its tenant" do
      allow(Apartment::Tenant).to receive(:create)

      expect {
        result = described_class.call(name: name, subdomain: subdomain)
        expect(result).to be_a(Company)
        expect(result).to have_attributes(name: name, subdomain: subdomain)
      }.to change(Company, :count).by(1)

      expect(Apartment::Tenant).to have_received(:create).with(subdomain)
    end

    it "does not create a tenant when company validation fails" do
      expect(Apartment::Tenant).not_to receive(:create)

      expect {
        expect {
          described_class.call(name: name, subdomain: "Invalid-Subdomain")
        }.to raise_error(ActiveRecord::RecordInvalid)
      }.not_to change(Company, :count)
    end

    it "rolls back the company when tenant creation fails" do
      allow(Apartment::Tenant).to receive(:create)
        .with(subdomain)
        .and_raise(StandardError, "Tenant creation failed")

      allow(connection).to receive(:schema_exists?)
        .with(subdomain)
        .and_return(false, true)

      expect(Apartment::Tenant).to receive(:drop).with(subdomain)

      expect {
        described_class.call(name: name, subdomain: subdomain)
      }.to raise_error(StandardError, "Tenant creation failed")

      expect(Company.exists?(subdomain: subdomain)).to be(false)
    end

    it "does not delete a schema that already exists" do
      allow(connection).to receive(:schema_exists?)
        .with(subdomain)
        .and_return(true)

      expect(Apartment::Tenant).not_to receive(:create)
      expect(Apartment::Tenant).not_to receive(:drop)

      expect {
        described_class.call(name: name, subdomain: subdomain)
      }.to raise_error(ArgumentError, /already exists/)

      expect(Company.exists?(subdomain: subdomain)).to be(false)
    end
    it "leaves no company or tenant schema when tenant creation fails" do
      allow(connection).to receive(:schema_exists?).and_call_original

      allow(Apartment::Tenant).to receive(:create).with(subdomain) do
          connection.execute(
              "CREATE SCHEMA #{connection.quote_table_name(subdomain)}"
          )

          raise StandardError, "Tenant creation failed"
      end

      expect {
          described_class.call(name: name, subdomain: subdomain)
      }.to raise_error(StandardError, "Tenant creation failed")

      expect(Company.exists?(subdomain: subdomain)).to be(false)
      expect(connection.schema_exists?(subdomain)).to be(false)
    end
  end
end
