# Supabase Seed Data

Seed files are for development and test data only. Production data must never be generated from demo seed files.

Keep seed data deterministic and safe to reset in local development.

Explicit operator-only exception: `full_roles_test_seed.sql` is a guarded live
test-account provisioning script requested by the operator, NOT demo business
data and NOT an automatic seed/migration. Read `docs/all-roles-testing-guide.md`
first. It does not fabricate approved identities or release feature flags.
`disable_full_roles_test_accounts.sql` disables its marked accounts after UAT.
Neither file should be executed by deployment/reset automation.

`pro_developer_demo_seed.sql` is an operator-only, staging-specific data set
for the server-flagged SwanSport Pro developer preview account. It must never
be included in migrations or production automation. Apply it manually only to
the staging project after reviewing its account and staging fixture guards.
`clear_pro_developer_demo_seed.sql` removes its deterministic rows while
retaining the developer account, assigned roles, and pre-existing role-test
club/field fixtures. Official federation program rows are intentionally
retained because the production authorization contract makes official history
immutable; the cleanup script removes only mutable demo data around them.
