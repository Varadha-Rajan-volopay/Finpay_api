require "rails_helper"

RSpec.describe "Tenant migrations" do
  self.use_transactional_tests = false

  let(:subdomain) { "migration_spec_tenant" }

  before do
    Apartment::Tenant.reset

    connection = ActiveRecord::Base.connection

    if connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end

    # Remove a Company left behind by an earlier test run.
    Company.where(subdomain: subdomain).delete_all
  end

  after do
    Apartment::Tenant.reset

    connection = ActiveRecord::Base.connection

    if connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end

    Company.where(subdomain: subdomain).delete_all
  end

  it "runs tenant migrations and creates the tenant tables" do
    company = Company.create!(
      name: "Migration Spec Company",
      subdomain: subdomain
    )

    connection = ActiveRecord::Base.connection

    # Create an empty tenant schema without copying the public schema.
    connection.execute(
      "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
    )

    Companies::TenantMigration.run!(company.subdomain)

    Apartment::Tenant.switch(company.subdomain) do
      tenant_connection = ActiveRecord::Base.connection

      expect(tenant_connection.data_source_exists?("users")).to be(true)
      expect(tenant_connection.data_source_exists?("companies")).to be(false)
      expect(tenant_connection.data_source_exists?("expenses")).to be(true)
    end
  end
end
