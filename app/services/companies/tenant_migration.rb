
require "rake"

module Companies
  class TenantMigration
    DEFAULT_CATEGORIES = [
      "Travel",
      "Food",
      "Accommodation",
      "Office Supplies",
      "Software",
      "Other"
    ].freeze

    def self.run!(tenant_name)
      Apartment::Tenant.switch(tenant_name) do
        migration_context = ActiveRecord::MigrationContext.new(
          Rails.root.join("db/tenant_migrate")
        )

        migration_context.migrate

        Expense.reset_column_information
        Category.reset_column_information

        seed_default_categories
      end
    ensure
      Apartment::Tenant.reset
    end

    def self.seed_default_categories
      DEFAULT_CATEGORIES.each do |category_name|
        Category.find_or_create_by!(name: category_name)
      end
    end

    private_class_method :seed_default_categories
  end
end
