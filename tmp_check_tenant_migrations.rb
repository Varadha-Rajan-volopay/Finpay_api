Company.pluck(:subdomain).each do |name|
  Apartment::Tenant.switch(name) do
    connection = ActiveRecord::Base.connection

    versions = if connection.data_source_exists?("schema_migrations")
      connection.select_values(
        "SELECT version FROM schema_migrations ORDER BY version"
      )
    else
      []
    end

    puts "\n#{name}:"
    puts versions
  end
end

Apartment::Tenant.reset
