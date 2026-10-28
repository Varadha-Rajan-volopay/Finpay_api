require "rails_helper"

RSpec.describe Companies::Provision do
  describe ".call" do
    let(:name) { "Acme Corp" }
    let(:subdomain) { "acme" }
    let(:connection) { ActiveRecord::Base.connection }

    after do
      Apartment::Tenant.reset

      if connection.schema_exists?(subdomain)
        Apartment::Tenant.drop(subdomain)
      end

      Company.find_by(subdomain: subdomain)&.delete
    end

    it "creates a company and provisions its tenant" do
      allow(Companies::TenantMigration).to receive(:run!)

      expect {
        result = described_class.call(name: name, subdomain: subdomain)

        expect(result).to be_a(Company)
        expect(result).to have_attributes(
          name: name,
          subdomain: subdomain
        )
      }.to change(Company, :count).by(1)

      expect(connection.schema_exists?(subdomain)).to be(true)
      expect(Companies::TenantMigration).to have_received(:run!).with(subdomain)
    end

    it "does not create a tenant when company validation fails" do
      expect(Companies::TenantMigration).not_to receive(:run!)

      expect {
        described_class.call(name: name, subdomain: "Invalid-Subdomain")
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(Company.exists?(subdomain: "Invalid-Subdomain")).to be(false)
      expect(connection.schema_exists?("Invalid-Subdomain")).to be(false)
    end

    it "rolls back the company when tenant migration fails" do
      allow(Companies::TenantMigration).to receive(:run!)
        .with(subdomain)
        .and_raise(StandardError, "Tenant creation failed")

      expect {
        described_class.call(name: name, subdomain: subdomain)
      }.to raise_error(StandardError, "Tenant creation failed")

      expect(Company.exists?(subdomain: subdomain)).to be(false)
      expect(connection.schema_exists?(subdomain)).to be(false)
    end

    it "does not delete a schema that already exists" do
      connection.execute(
        "CREATE SCHEMA #{connection.quote_table_name(subdomain)}"
      )

      expect(Companies::TenantMigration).not_to receive(:run!)

      expect {
        described_class.call(name: name, subdomain: subdomain)
      }.to raise_error(ArgumentError, /already exists/)

      expect(Company.exists?(subdomain: subdomain)).to be(false)
      expect(connection.schema_exists?(subdomain)).to be(true)
    end

    it "leaves no company or tenant schema when tenant migration fails" do
      allow(Companies::TenantMigration).to receive(:run!)
        .with(subdomain)
        .and_raise(StandardError, "Tenant creation failed")

      expect {
        described_class.call(name: name, subdomain: subdomain)
      }.to raise_error(StandardError, "Tenant creation failed")

      expect(Company.exists?(subdomain: subdomain)).to be(false)
      expect(connection.schema_exists?(subdomain)).to be(false)
    end
  end
end
