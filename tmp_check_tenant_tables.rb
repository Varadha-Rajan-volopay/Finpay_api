Company.pluck(:subdomain).each do |name|
  Apartment::Tenant.switch(name) do
    connection = ActiveRecord::Base.connection

    tables = %w[categories expenses receipts].select do |table|
      connection.data_source_exists?(table)
    end

    puts "#{name}: #{tables.join(', ')}"
  end
end

Apartment::Tenant.reset
