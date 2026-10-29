
require "rails_helper"

RSpec.describe "Tenant migrations" do
  let(:subdomain) { "migration_spec_tenant" }

  after do
    Apartment::Tenant.reset

    if ActiveRecord::Base.connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end
  end

  it "runs tenant migrations and creates the users table" do
    company = Company.create!(
      name: "Migration Spec Company",
      subdomain: subdomain
    )

    # Create an empty tenant schema without copying the public schema.
    ActiveRecord::Base.connection.execute(
      "CREATE SCHEMA #{ActiveRecord::Base.connection.quote_table_name(company.subdomain)}"
    )

    Companies::TenantMigration.run!(company.subdomain)

    Apartment::Tenant.switch(company.subdomain) do
      connection = ActiveRecord::Base.connection

      expect(connection.data_source_exists?("users")).to be(true)

      expect(
        connection.data_source_exists?("companies")
      ).to be(false)

      expect(
        connection.data_source_exists?("expenses")
      ).to be(false)
    end
  end
end
