connection = ActiveRecord::Base.connection

schemas = %w[public acme acme_test_01 beta_test_01 vol]

schemas.each do |schema|
  puts "\n#{schema.upcase} MIGRATIONS:"

  versions = connection.select_values(
    "SELECT version FROM #{connection.quote_table_name(schema)}.schema_migrations ORDER BY version"
  )

  puts versions
end
