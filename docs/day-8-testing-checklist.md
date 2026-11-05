# Day 8 — Testing In Depth Checklist

Date: 2026-11-05

## Coverage audit
- [x] SimpleCov enabled.
- [x] Branch coverage enabled.
- [x] Weak coverage areas audited and prioritized.
- [x] CI line coverage threshold configured at 90%.
- [x] Full suite achieved 93.06% line coverage and 84.06% branch coverage.

## Test coverage
- [x] Authentication success and failure paths.
- [x] Expense CRUD, filtering, pagination and workflow request specs.
- [x] Workflow transitions and invalid transitions.
- [x] Workflow idempotency and rollback cases.
- [x] Worker success, failure, retry and idempotency cases.
- [x] Service and model validation failure paths.
- [x] FactoryBot admin and approved traits.
- [x] Faker and minimal valid factory defaults.
- [x] Health, login and PUT endpoint request specs added.

## Multi-tenancy and authentication
- [x] Shared tenant test helper/context created.
- [x] Tenant schemas cleaned up after tests.
- [x] Cross-tenant isolation tested for tenant-owned resources.
- [x] Real signed JWT authentication helper created.
- [x] Expired, revoked and wrong-tenant token helpers created.

## Test quality
- [x] Full suite passed: 250 examples, 0 failures.
- [x] Randomized run with seed 67890 passed.
- [x] Earlier randomized run with seed 12345 passed.
- [x] Workflow transition mutation detected by tests.
- [x] Tenant header override mutation detected by tests.
- [x] Money precision mutation detected by tests.
- [x] RuboCop formatting offenses corrected.
- [x] git diff --check passed.
- [x] Latest full-suite runtime: 3 minutes 20.5 seconds.

## CI and final review
- [x] CI workflow configured to enforce 90% line coverage.
- [ ] GitHub Actions CI run verified.
- [ ] Final review and commit completed.
