# Technology Stack

**Analysis Date:** 2026-10-05

## Languages

**Primary:**
- Dart (SDK `>=3.5.0 <4.0.0`) - Used across Flutter mobile/web apps and shared core/data packages.
- SQL (PostgreSQL 15+ / Supabase PL/pgSQL) - 76 sequential numbered migrations with RLS and security definer functions.

**Secondary:**
- JavaScript (Node.js / Cloudflare Pages Functions) - Used for Edge functions (`apps/swansport_app/functions`), RSS parsing, and push relay.
- Python 3 - Developer tooling and migration checks (`tools/check_migrations.py`, `tools/bundle_migrations.py`, `tools/check_faq.py`).

## Runtime

**Environment:**
- Flutter 3.24+ / Dart SDK 3.5+
- Node.js 20+ (Cloudflare Wrangler, Melos, tooling)
- Supabase (PostgreSQL with extensions: `pg_cron`, `pgcrypto`, `postgis`/`earthdistance`)

**Package Manager:**
- Melos `^8.2.2` (Monorepo manager defined in root `pubspec.yaml` and `melos.yaml`)
- Pub (Dart package manager with workspace resolution `resolution: workspace`)
- Lockfile: `pubspec.lock` present and tracked.

## Frameworks

**Core:**
- Flutter (Material 3) - Core UI framework for mobile (`apps/swansport_app`) and desktop console (`apps/swansport_console`).
- Riverpod (`flutter_riverpod: ^2.6.1`) - Declarative state management and dependency injection across apps and `swansport_data`.
- GoRouter (`go_router: ^14.6.2`) - Declarative routing in `apps/swansport_console`.

**Testing:**
- `flutter_test` (SDK) - Unit, widget, and golden tests.
- `lints: ^5.0.0` & `flutter_lints: ^5.0.0` - Dart static analysis.

**Build/Dev:**
- Melos - Multi-package workspace orchestration (`melos run run:dev`, `melos run format:check`).
- Cloudflare Wrangler - Pages Functions development and deployment.

## Key Dependencies

**Critical:**
- `supabase_flutter: ^2.8.0` - Supabase client for authentication, database, realtime subscriptions, and RPC execution.
- `flutter_riverpod: ^2.6.1` - State management separating data providers from UI widgets.
- `firebase_core: ^4.14.0` & `firebase_messaging: ^16.6.0` - Push notification delivery on Android/iOS.
- `geolocator: ^14.0.3` - Geolocation services for sports court proximity sorting.

**Infrastructure & Utilities:**
- `google_fonts: ^6.2.1` - Plus Jakarta Sans & Sora typography.
- `qr_flutter: ^4.1.0` - QR code generation for credentials and event verification.
- `file_picker: ^12.0.0` & `path_provider: ^2.1.6` - Document and attachment handling.
- `apk_sideload: ^0.0.2` & `package_info_plus: ^10.2.1` - In-app auto-update checks for Android APKs.

## Configuration

**Environment:**
- Multi-environment entry points: `lib/main_development.dart`, `lib/main_staging.dart`, `lib/main_production.dart`.
- App environment variables passed via `AppEnvironment` configuration in `packages/swansport_core`.
- `.env.example` tracks expected Supabase keys and API endpoints.

**Build:**
- Root `analysis_options.yaml` enforcing strict casts, strict inference, and strict raw types.
- `melos.yaml` defining scripts for formatting and targeted runs.

## Platform Requirements

**Development:**
- Flutter SDK `>=3.5.0`
- Git
- Python 3.10+ (for tools)
- Node.js 18+

**Production:**
- Android: APK / Google Play
- Web: Cloudflare Pages (hosted desktop console and mobile web shell)
- Supabase: Managed cloud instance with Vault for secrets

---

*Stack analysis: 2026-10-05*
