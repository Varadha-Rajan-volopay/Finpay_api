require "rails_helper"

RSpec.describe "Tenant migrations" do
  let(:subdomain) { "migration_spec_tenant" }

  after do
    Apartment::Tenant.drop(subdomain) if
      ActiveRecord::Base.connection.schema_exists?(subdomain)
  end

  it "runs migrations and creates tenant tables" do
    company = Company.create!(
      name: "Migration Spec Company",
      subdomain: subdomain
    )

    Apartment::Tenant.create(company.subdomain)

    Apartment::Tenant.switch(company.subdomain) do
      migration_context = ActiveRecord::MigrationContext.new(
        Rails.root.join("db/migrate")
      )

      migration_context.migrate

      expect(
        ActiveRecord::Base.connection.data_source_exists?("expenses")
      ).to be(true)
    end
  end
end
