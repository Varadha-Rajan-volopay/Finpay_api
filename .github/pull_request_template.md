## Description
<!-- Summarize what this PR implements and why. -->

- Configure the Rails API development and test environment.
- Add Company model validations and a unique subdomain index.
- Implement schema-per-tenant provisioning with failure cleanup.
- Add tenant-switching and provisioning specs.
- Configure GitHub Actions to run quality and test checks.

## Tests and CI
- [ ] RuboCop — passed locally; 32 files, zero offenses.
- [ ] bundler-audit — passed locally; no vulnerabilities found.
- [ ] RSpec — passed locally; 12 examples, 0 failures.
- [ ] Brakeman — verify in GitHub Actions (local Windows environment issue).
- [ ] GitHub Actions checks are green.

## Review checklist
- [ ] Tests added or updated, CI green
- [ ] Cross-tenant and cross-user access specs where data is read or written
- [ ] No secrets, tokens or personal data in code, logs or fixtures
- [ ] Migration reviewed for locking and for all tenant schemas
- [ ] Endpoint documented
