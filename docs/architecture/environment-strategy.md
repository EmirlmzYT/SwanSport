# Environment Strategy

SwanSport uses isolated development, staging, and production backends.

Development can use local Supabase or a dedicated development project. Staging
and production use different Supabase and Firebase projects and never share demo
seed data. Missing compile-time backend settings mean fixture mode; source code
contains no fallback URL or publishable key.

Environment values are documented in `.env.example`:

```env
APP_ENV=development
SUPABASE_URL=
SUPABASE_ANON_KEY=
SENTRY_DSN=
```

Real `.env`, `.env.development`, and `.env.production` files are ignored by Git. Service role keys must never be used in Flutter code. Server-only secrets belong in Supabase Edge Function secrets or deployment environment variables.

The Flutter app has separate entrypoints:

- `lib/main_development.dart`
- `lib/main_production.dart`

The manual `Phase 3 Staging Acceptance` workflow is scoped to the GitHub
`staging` environment and rejects the production project reference before any
migration or build step. See `docs/phase3-staging-and-device-acceptance.md`.
