connection = ActiveRecord::Base.connection

puts "PUBLIC MIGRATIONS:"
puts connection.select_values(
  "SELECT version FROM public.schema_migrations ORDER BY version"
)

puts "PUBLIC TABLES:"
puts connection.select_values(<<~SQL)
  SELECT tablename
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY tablename
SQL

puts "PUBLIC FOREIGN KEYS:"
puts connection.select_all(<<~SQL).to_a
  SELECT
    conrelid::regclass AS from_table,
    confrelid::regclass AS to_table,
    conname AS constraint_name
  FROM pg_constraint
  WHERE contype = 'f'
    AND connamespace = 'public'::regnamespace
SQL
