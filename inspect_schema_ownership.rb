connection = ActiveRecord::Base.connection

puts "SCHEMAS AND MIGRATION TABLES:"
puts connection.select_all(<<~SQL).to_a
  SELECT
    n.nspname AS schema_name,
    to_regclass(format('%I.schema_migrations', n.nspname)) AS migration_table
  FROM pg_namespace n
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY n.nspname
SQL

puts "\nUSERS / EXPENSES / RECEIPTS TABLE LOCATIONS:"
puts connection.select_all(<<~SQL).to_a
  SELECT
    schemaname,
    tablename
  FROM pg_tables
  WHERE tablename IN ('users', 'expenses', 'receipts')
  ORDER BY schemaname, tablename
SQL

puts "\nPUBLIC TABLE ROW COUNTS:"
%w[users expenses receipts].each do |table|
  count = connection.select_value("SELECT COUNT(*) FROM public.#{connection.quote_table_name(table)}")
  puts "#{table}: #{count}"
end

puts "\nFOREIGN KEYS REFERENCING USERS:"
puts connection.select_all(<<~SQL).to_a
  SELECT
    conrelid::regclass AS from_table,
    confrelid::regclass AS to_table,
    conname AS constraint_name
  FROM pg_constraint
  WHERE contype = 'f'
    AND confrelid = 'public.users'::regclass
SQL
