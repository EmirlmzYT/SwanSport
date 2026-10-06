# External Integrations

**Analysis Date:** 2026-10-05

## APIs & External Services

**BaaS & Database:**
- Supabase - Relational database, Auth, Storage, and Realtime WebSocket channels.
  - SDK/Client: `supabase_flutter: ^2.8.0`
  - Auth: `SUPABASE_URL` and `SUPABASE_ANON_KEY`

**Push Notifications:**
- Firebase Cloud Messaging (FCM) - Cross-platform push delivery.
  - SDK/Client: `firebase_core: ^4.14.0`, `firebase_messaging: ^16.6.0`
  - Server Relay: Cloudflare Pages Function `apps/swansport_app/functions/api/push.js`

**Location Services:**
- Native GPS / Geolocator - Distance calculation for sports facilities.
  - SDK/Client: `geolocator: ^14.0.3`
  - Server validation: `meters_between` PostGIS function in Supabase.

**News Aggregation:**
- RSS Feeds - Club and federation news ingestion.
  - Relay/Parser: `apps/swansport_app/functions/api/rss.js`

## Data Storage

**Databases:**
- PostgreSQL on Supabase (76 sequential idempotent migrations in `supabase/migrations/`).
  - Connection: `supabase_flutter` client via HTTPS/REST and Realtime WSS.
  - Client: Direct RPC calls and PostgREST table querying encapsulated in `swansport_data`.

**File Storage:**
- Supabase Storage buckets: `documents`, `avatars`, `club_assets`, `credentials`.
  - Managed via RLS in `0005_storage.sql` and `0068_identity_customization.sql`.

**Caching:**
- Riverpod In-Memory Caching - State-managed provider caching with invalidation hooks.
- Local Storage: `shared_preferences: ^2.5.0` for local user preferences and cached flags.

## Authentication & Identity

**Auth Provider:**
- Supabase Auth (GoTrue)
  - Implementation: Email/password, phone verification, and custom role resolution through `profiles` and `club_memberships`.
  - RBAC engine: `SwanAccess` in `packages/swansport_data/lib/src/access.dart` combining profile roles and verified credentials.

## Monitoring & Observability

**Error Tracking:**
- Custom logging via `debugPrint` and diagnostic audit tables: `expense_audit_logs`, `reminder_log`, `attendance_op_logs`.

**Logs:**
- Server-side PostgreSQL logs and Supabase Dashboard query metrics.
- Cron logs managed by `pg_cron` jobs.

## CI/CD & Deployment

**Hosting:**
- Cloudflare Pages - Web deployment for both `swansport_app` and `swansport_console`.
- Android APK - Direct distribution and sideload update checker (`apps/swansport_app/lib/features/settings/presentation/update_checker.dart`).

**CI Pipeline:**
- Melos-based validation (`melos run format:check`, `check_migrations.py`, `check_faq.py`).

## Environment Configuration

**Required env vars:**
- `SUPABASE_URL`: Supabase project URL.
- `SUPABASE_ANON_KEY`: Public anonymous API key.
- `FCM_SERVER_KEY` / `SERVICE_ACCOUNT`: Used in Cloudflare Functions for notification dispatch.

**Secrets location:**
- Client secrets: `.env` (development) / Compile-time environment arguments `--dart-define`.
- Server secrets: Supabase Vault (`select vault.create_secret(...)`).

## Webhooks & Callbacks

**Incoming:**
- Cloudflare Pages Function endpoints (`/api/push`, `/api/rss`).

**Outgoing:**
- Supabase Database Webhooks invoking Edge functions for FCM push triggers.

---

*Integration audit: 2026-10-05*
