require "rails_helper"

RSpec.describe "Tenant switching" do
  let(:tenant_name) { "tenant_switch_spec" }

  it "switches into the tenant and restores the original tenant" do
    original_tenant = Apartment::Tenant.current

    Apartment::Tenant.create(tenant_name)

    Apartment::Tenant.switch(tenant_name) do
      expect(Apartment::Tenant.current).to eq(tenant_name)
    end

    expect(Apartment::Tenant.current).to eq(original_tenant)
  ensure
    if ActiveRecord::Base.connection.schema_exists?(tenant_name)
      Apartment::Tenant.drop(tenant_name)
    end
  end
end
