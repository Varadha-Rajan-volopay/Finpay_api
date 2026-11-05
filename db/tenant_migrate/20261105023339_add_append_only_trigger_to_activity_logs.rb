class AddAppendOnlyTriggerToActivityLogs < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute <<~SQL
        CREATE OR REPLACE FUNCTION prevent_activity_logs_mutation()
        RETURNS trigger AS $$
        BEGIN
          RAISE EXCEPTION 'Activity logs are append-only'
            USING ERRCODE = '55000';
        END;
        $$ LANGUAGE plpgsql;
      SQL

      execute <<~SQL
        CREATE TRIGGER prevent_activity_logs_mutation
        BEFORE UPDATE OR DELETE ON activity_logs
        FOR EACH ROW
        EXECUTE FUNCTION prevent_activity_logs_mutation();
      SQL
    end
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS prevent_activity_logs_mutation
      ON activity_logs;
    SQL

    execute <<~SQL
      DROP FUNCTION IF EXISTS prevent_activity_logs_mutation();
    SQL
  end
end
