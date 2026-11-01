
module Companies
  class Provision
    def self.call(name:, subdomain:)
      tenant_creation_attempted = false

      if ActiveRecord::Base.connection.schema_exists?(subdomain)
        raise ArgumentError, "Tenant schema already exists: #{subdomain}"
      end

      company = ActiveRecord::Base.transaction do
        company = Company.create!(
          name: name,
          subdomain: subdomain
        )

        tenant_creation_attempted = true
        Apartment::Tenant.create(company.subdomain)

        company
      end

      company
    rescue StandardError
      if tenant_creation_attempted &&
         ActiveRecord::Base.connection.schema_exists?(subdomain)
        Apartment::Tenant.drop(subdomain)
      end

      raise
    end
  end
end
