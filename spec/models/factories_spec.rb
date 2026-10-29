require "rails_helper"

RSpec.describe "FactoryBot factories" do
  it "has valid factories" do
    tenant_name = "factory_lint_#{SecureRandom.hex(4)}"
    connection = ActiveRecord::Base.connection

    begin
      connection.execute(
        "CREATE SCHEMA #{connection.quote_table_name(tenant_name)}"
      )

      Companies::TenantMigration.run!(tenant_name)

      Apartment::Tenant.switch(tenant_name) do
        FactoryBot.lint(strategy: :build)
      end
    ensure
      Apartment::Tenant.reset

      if connection.schema_exists?(tenant_name)
        Apartment::Tenant.drop(tenant_name)
      end
    end
  end
end
