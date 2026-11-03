sql = "SELECT table_schema, table_name FROM information_schema.tables WHERE table_name IN ('users', 'refresh_tokens', 'jwt_denylists') ORDER BY table_schema, table_name"
puts ActiveRecord::Base.connection.select_all(sql).to_a
