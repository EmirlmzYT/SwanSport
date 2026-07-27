# Environment Strategy

SwanSport starts with a development environment and later adds a separate production environment.

Development can use local Supabase or a dedicated development Supabase project. Production must use a separate Supabase project and must not share demo seed data.

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

No real Supabase or Firebase connection is created in this skeleton.
