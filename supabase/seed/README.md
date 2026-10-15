# Supabase Seed Data

Seed files are for development and test data only. Production data must never be generated from demo seed files.

Keep seed data deterministic and safe to reset in local development.

Explicit operator-only exception: `full_roles_test_seed.sql` is a guarded live
test-account provisioning script requested by the operator, NOT demo business
data and NOT an automatic seed/migration. Read `docs/all-roles-testing-guide.md`
first. It does not fabricate approved identities or release feature flags.
`disable_full_roles_test_accounts.sql` disables its marked accounts after UAT.
Neither file should be executed by deployment/reset automation.
