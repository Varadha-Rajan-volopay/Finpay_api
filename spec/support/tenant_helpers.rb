# frozen_string_literal: true

module TenantHelpers
  def create_test_tenant(name: "Test Company")
    subdomain = "test_#{SecureRandom.hex(4)}"

    company = Companies::Provision.call(
      name: name,
      subdomain: subdomain
    )

    (@tenant_schema_companies ||= []) << company
    company
  end

  def create_two_test_tenants
    [
      create_test_tenant(name: "Tenant A"),
      create_test_tenant(name: "Tenant B")
    ]
  end

  def with_test_tenant(company, &block)
    Apartment::Tenant.switch(company.subdomain, &block)
  end

  def cleanup_test_tenant_schemas
    Apartment::Tenant.reset

    Array(@tenant_schema_companies).each do |company|
      if ActiveRecord::Base.connection.schema_exists?(company.subdomain)
        Apartment::Tenant.drop(company.subdomain)
      end

      Company.find_by(id: company.id)&.delete
    end

    @tenant_schema_companies = []
    Apartment::Tenant.reset
  end
end

RSpec.shared_context "tenant schemas" do
  self.use_transactional_tests = false

  include TenantHelpers

  before do
    @tenant_schema_companies = []
  end

  after do
    cleanup_test_tenant_schemas
  end
end

RSpec.configure do |config|
  config.include TenantHelpers
end
