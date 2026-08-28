# Backend setup (Supabase)

This guide connects the Flutter app to a live Supabase backend. Until the keys
are supplied, the app runs entirely on fixtures — no backend required.

## 1. Create a Supabase project

1. Sign in at <https://supabase.com> (GitHub login works).
2. **New project** → name `swansport`, set a database password (store it
   safely), region **Central EU (Frankfurt)**, Free plan.
3. After provisioning, open **Settings → API** and copy:
   - **Project URL** (`https://xxxx.supabase.co`)
   - the **anon / publishable** key (never the `service_role` / secret key)

## 2. Apply the database schema

In the Supabase dashboard: **SQL Editor → New query**, then run these files
**in order**:

1. `supabase/migrations/0001_foundation.sql` — tables, enums, triggers
2. `supabase/migrations/0002_rls_policies.sql` — Row Level Security + helpers

## 3. Sign up, then seed demo data

1. Run the app connected to Supabase (see below) and **sign up** once so your
   auth user + profile exist.
2. Edit `supabase/seed/demo_seed.sql`, replace `REPLACE_WITH_YOUR_EMAIL` with
   your signup email, and run it in the SQL Editor. It creates the demo club
   "Kadıköy SK" with three athletes and makes you its admin.

## 4. Run the app against Supabase

Pass the keys as `--dart-define`. With them present the app switches from
fixtures to live repositories automatically; without them it stays on fixtures.

```bash
cd apps/swansport_app
flutter run -d chrome -t lib/main_development.dart \
  --dart-define=APP_ENV=development \
  --dart-define=APP_NAME=SwanSport \
  --dart-define=ENABLE_DEBUG_TOOLS=true \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... (or sb_publishable_...)
```

To keep secrets out of shell history you can use a define file:

```bash
flutter run -t lib/main_development.dart --dart-define-from-file=env/dev.json
```

## How the switch works

- `SupabaseConfig.fromCompileTime()` reads `SUPABASE_URL` / `SUPABASE_ANON_KEY`.
- `bootstrap()` initializes Supabase only when both are present.
- `isSupabaseEnabledProvider` exposes that state; each feature's repository
  provider picks the Supabase implementation when enabled, else the fixture one.

This means partially-migrated features keep working: unconverted features fall
back to fixtures even while connected to Supabase.

## Security notes

- The anon/publishable key is safe to embed in the client build. Data
  protection comes from the RLS policies in `0002_rls_policies.sql`.
- Never embed the `service_role` / secret key in the app.
- Keep `.env*` files and any `env/*.json` define files out of source control.
