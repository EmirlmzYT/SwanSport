# SwanSport

SwanSport is a modular sports management platform for clubs, federations, coaches, athletes, parents, officials, and administrators.

## Project status

This repository currently contains only the approved monorepo skeleton. Product features, Supabase schema, Firebase setup, and final design tokens have not been implemented yet.

## Technology stack

- Flutter for Android, iOS, Web, and Windows
- Supabase for backend, PostgreSQL, Auth, Storage, and Edge Functions
- Riverpod for state management
- Material 3 based SwanSport design system
- Dart workspace and Melos for monorepo management
- GitHub Actions for basic CI

## Repository structure

```text
apps/swansport_app                 Main Flutter application
packages/swansport_core            Shared core utilities
packages/swansport_design_system   Shared Flutter design system
packages/swansport_models          Shared Dart models and value types
packages/swansport_branch_engine   Shared branch engine contracts
supabase/                          Future migrations, policies, seeds, functions, tests
docs/                              Architecture, product, security, and ADR documentation
scripts/                           Future local automation scripts
```

## Requirements

- Flutter SDK
- Dart SDK included with Flutter
- Melos
- Supabase CLI, when database work starts

On Windows, verify tools are available:

```powershell
flutter --version
dart --version
melos --version
```

Install Melos after Flutter is installed:

```powershell
dart pub global activate melos
```

## Initial setup

```powershell
melos bootstrap
```

## Melos commands

```powershell
melos analyze
melos format
melos run format:check
melos test
melos clean
melos run run:dev
melos run run:web
```

## Run development app

```powershell
cd apps/swansport_app
flutter run -t lib/main_development.dart --dart-define=APP_ENV=development --dart-define=APP_NAME=SwanSport --dart-define=ENABLE_DEBUG_TOOLS=true
```

## Run production entrypoint locally

This does not connect production services. It only validates production compile-time configuration.

```powershell
cd apps/swansport_app
flutter run -t lib/main_production.dart --dart-define=APP_ENV=production --dart-define=APP_NAME=SwanSport --dart-define=ENABLE_DEBUG_TOOLS=false
```

## Web preview

```powershell
cd apps/swansport_app
flutter run -d chrome -t lib/main_development.dart --dart-define=APP_ENV=development --dart-define=APP_NAME=SwanSport --dart-define=ENABLE_DEBUG_TOOLS=true
```

## Test and analysis

```powershell
melos run format:check
melos analyze
melos test
```

## Environment variables

Copy `.env.example` to a local `.env.development` file when environment loading is implemented. Do not commit real secrets.

Supabase is not connected yet. `SUPABASE_URL` and `SUPABASE_ANON_KEY` are placeholders.

Current environment values are read at compile time with `String.fromEnvironment`.

Supported non-secret values:

```text
APP_ENV=development|production
APP_NAME=SwanSport
ENABLE_DEBUG_TOOLS=true|false
```

Use `--dart-define` for local commands. `--dart-define-from-file` can be added later for non-secret local convenience files, but real secrets must still stay out of Flutter builds.

## Contribution and coding rules

- Keep UI, application logic, repositories, services, and database access separated.
- Do not call Supabase directly from widgets.
- Do not add unused third-party packages.
- Keep sensitive keys out of source control.
- Add RLS policies with sensitive database tables.
- Keep each change scoped to the requested task.

## Not implemented yet

- Supabase project connection
- Firebase and FCM
- Database migrations
- Real design tokens
- Authentication, clubs, athletes, payments, notifications, or admin features
