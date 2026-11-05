# frozen_string_literal: true

StrongMigrations.safe_by_default = true

StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

StrongMigrations.start_after = 20261104120000
