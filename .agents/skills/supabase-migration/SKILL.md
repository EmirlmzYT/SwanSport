---
name: supabase-migration
description: Add a safe SwanSport Supabase migration while preserving RLS, grants, RPC contracts, and local-only validation.
---

# Supabase migration

1. Read `supabase/README.md`, `supabase/migrations/README.md`, and the latest related migration.
2. Search for existing tables, columns, RPCs, policies, grants, triggers, and tests before creating a new one.
3. Add one ordered, idempotent migration in `supabase/migrations/`; never edit an applied migration.
4. Enforce authorization in RLS or a guarded function; do not rely on hidden buttons or client roles.
5. Preserve `PUBLIC`, `anon`, and `authenticated` grant behavior explicitly.
6. Handle changed function signatures and return types safely; do not leave ambiguous RPC overloads.
7. Run `npm test --prefix tools` and relevant `tools/check_*.py` checks when available.
8. Do not run `supabase link`, `db push`, remote SQL, or a production connection without explicit authorization.
