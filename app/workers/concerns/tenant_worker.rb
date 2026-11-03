# frozen_string_literal: true

module TenantWorker
  extend ActiveSupport::Concern

  included do
    sidekiq_options retry: 5
  end

  private

  def with_tenant(tenant_id)
    company = Company.find_by(id: tenant_id)

    raise ActiveRecord::RecordNotFound, "Company not found: #{tenant_id}" unless company

    Apartment::Tenant.switch(company.subdomain) do
      yield
    end
  ensure
    Apartment::Tenant.reset
  end
end
