module Companies
  class TenantMigration
    def self.run!(tenant_name)
      Apartment::Tenant.switch(tenant_name) do
        migration_context =
          ActiveRecord::MigrationContext.new(
            Rails.root.join("db/tenant_migrate")
          )

        migration_context.migrate
      end
    ensure
      Apartment::Tenant.reset
    end
  end
end
