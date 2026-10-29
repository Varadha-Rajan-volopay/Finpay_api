Company.pluck(:subdomain).each do |name|
  Apartment::Tenant.switch(name) do
    schema_names = ActiveRecord::Base.connection.select_values(
      "SELECT n.nspname
       FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE c.relname = 'expenses'
       AND c.relkind = 'r'
       AND n.nspname IN ('public', '#{name}')"
    )

    puts "#{name} -> #{schema_names.join(', ')}"
  end
end

Apartment::Tenant.reset
