# Supabase migrations

- Add schema changes only as a new ordered migration; never edit applied migrations.
- Make migrations idempotent and give each migration one clear purpose.
- Preserve RLS, function grants, constraints, triggers, and audit behavior.
- Search for an existing RPC, table, column, policy, and migration before creating one.
- Do not change an RPC signature or return type without handling its old definition safely.
- Do not use client-supplied role claims as authorization.
- Do not run `supabase link`, `db push`, or remote SQL without explicit permission.
- Use local/isolated tool checks for SQL work; report any check that cannot run.
