# frozen_string_literal: true

module TenantWorker
  extend ActiveSupport::Concern

  private

  def with_tenant(tenant_id)
    company = Company.find_by(id: tenant_id)

    unless company
      Rails.logger.warn(
        "TenantWorker: Company not found for tenant_id=#{tenant_id}; skipping job"
      )
      return
    end

    Apartment::Tenant.switch(company.subdomain) do
      yield
    end
  end
end
