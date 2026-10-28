module Companies
  class Provision
    def self.call(name:, subdomain:)
      connection = ActiveRecord::Base.connection

      if connection.schema_exists?(subdomain)
        raise ArgumentError, "Tenant schema already exists: #{subdomain}"
      end

      company = nil
      tenant_creation_attempted = false

      company = Company.create!(
        name: name,
        subdomain: subdomain
      )

      tenant_creation_attempted = true

      connection.execute(
        "CREATE SCHEMA #{connection.quote_table_name(subdomain)}"
      )

      Companies::TenantMigration.run!(subdomain)

      Apartment::Tenant.switch(subdomain) do
        yield company if block_given?
      end

      company
    rescue StandardError
      Apartment::Tenant.reset

      if tenant_creation_attempted &&
         ActiveRecord::Base.connection.schema_exists?(subdomain)
        Apartment::Tenant.drop(subdomain)
      end

      company&.delete if company&.persisted?

      raise
    ensure
      Apartment::Tenant.reset
    end
  end
end
