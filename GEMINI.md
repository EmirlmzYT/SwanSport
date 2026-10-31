# SwanSport Agent Rules

## Project

- Build SwanSport, a Turkish sports-club management platform and sports network.
- Maintain three Flutter clients: `swansport_app` (Android/web), `swansport_console` (desktop web), and `swansport_pro` (professional operations).
- Treat `packages/swansport_data` as the shared Supabase data layer; do not put UI code in it.
- Use no CMS; PostgreSQL schema and authorization live in Supabase migrations and RLS policies.

## Verified stack

- Use Flutter 3.47.7 in CI; root Dart constraint is `>=3.5.0 <4.0.0`.
- Use Dart, Flutter Material 3, Riverpod 2.6, GoRouter 14, Supabase Flutter 2.8, and Melos 8.2.
- Use Supabase PostgreSQL, Auth, Storage, RLS, RPCs, and SQL migrations.
- Use Cloudflare Pages plus Pages Functions for web deployment; use Node 22 and Python 3.13 for backend checks.
- Use Supabase CLI 2.121.0 only for explicitly authorized local or staging work.

## Repository map

- `apps/swansport_app/`: mobile/web UI, routes, assets, Pages Functions, and Android/iOS hosts.
- `apps/swansport_console/`: desktop-only web administration UI.
- `apps/swansport_pro/`: professional operations Flutter client.
- `packages/swansport_data/`: services, models, Supabase calls, and Riverpod providers.
- `packages/swansport_core/`, `models/`, `branch_engine/`, `design_system/`, `pro_features/`: shared contracts and UI/domain packages.
- `supabase/migrations/`: ordered, idempotent schema and RLS source of truth.
- `supabase/functions/`, `policies/`, `seed/`, `tests/`: backend support material.
- `tools/`: locked Node/Python SQL, release, and contract checks.
- `.github/workflows/`: CI, staged migrations, builds, releases, and deployments.
- `env/`, `supabase/config.toml`, and platform config files: protected configuration; do not edit unless explicitly asked.

## Implementation rules

- Read the nearest `README.md`, existing service/provider, route, model, and migration before editing.
- Make the smallest change that fulfils the request.
- Match null safety, strict analysis, trailing commas, explicit return types, `final`, and current naming.
- Reuse existing services, providers, RPCs, models, widgets, and tokens; do not invent APIs or duplicate functions.
- Keep Supabase calls and providers in `packages/swansport_data/lib/src/`; never call Supabase directly from a widget.
- Calculate access only through `SwanAccess`; enforce every authorization rule in RLS or a guarded RPC.
- Use parameterized Supabase/PostgREST APIs and SQL function parameters; never concatenate untrusted SQL.
- Escape or safely render user-controlled text; never introduce unsafe HTML, JavaScript interpolation, or untrusted URLs.
- Preserve public metadata, manifests, deep links, page titles, and share previews unless the task explicitly changes them.

## Prohibitions

- Do not edit `.env`, `env/`, credentials, Supabase connection configuration, signing files, or Firebase files without explicit permission.
- Do not connect to production, run `supabase link`, `db push`, deploy, publish, or trigger remote migrations without explicit permission.
- Do not replace an entire file, reformat unrelated code, perform speculative refactors, or add dependencies unless explicitly requested.
- Do not remove RLS, grants, validation, feature gates, routes, migrations, tests, or existing public behavior to make a task easier.

## Working and verification

- State assumptions; if code or requirements do not answer a material question, stop and ask.
- Report every changed file and its purpose after the change.
- Run checks from the affected package: `flutter analyze --no-pub --no-fatal-infos` and `flutter test --no-pub`.
- Run `dart format --output=none --set-exit-if-changed <changed Dart paths>` for Dart changes.
- For SQL/Pages Function or release-contract work, run `npm ci --prefix tools --ignore-scripts --no-audit --no-fund` then `npm test --prefix tools` when dependencies are available.
- For web entrypoint changes, build or open the affected development entrypoint locally; do not use a live database unless authorized.
- If any required format, analysis, test, or build check fails, diagnose and fix the in-scope cause, rerun the failed check, then report evidence; if blocked, report the exact failure and required decision.
