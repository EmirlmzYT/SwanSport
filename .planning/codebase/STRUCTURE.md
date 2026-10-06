# Codebase Structure

**Analysis Date:** 2026-10-05

## Directory Layout

```
c:\Users\Nisa\Desktop\SwanSpor V1.0.5/
├── apps/
│   ├── swansport_app/               # Mobile & web hybrid Flutter app
│   │   ├── functions/               # Cloudflare Pages Functions (rss, push)
│   │   ├── lib/
│   │   │   ├── app/                 # App root, routing, shell navigation
│   │   │   ├── features/            # 29 feature modules (auth, attendance, finance, etc.)
│   │   │   └── shared/              # Reusable app-level widgets and helpers
│   │   └── test/                    # 40+ app-level tests
│   └── swansport_console/           # Desktop management console (Web >=900px)
│       ├── lib/                     # Console views, tables, and modules
│       └── test/                    # Console unit & widget tests
├── packages/
│   ├── swansport_branch_engine/     # Branch-specific training rules (pure Dart)
│   ├── swansport_core/              # Environment config, contracts, types
│   ├── swansport_data/              # Shared Supabase services & Riverpod providers
│   ├── swansport_design_system/     # Design tokens (SwanType, SwanPalette)
│   └── swansport_models/            # Shared data transfer objects
├── supabase/
│   └── migrations/                  # 76 numbered idempotent SQL migrations
├── tools/                           # Verification and maintenance Python scripts
├── docs/                            # Architectural design documents
├── melos.yaml                       # Monorepo configuration
├── analysis_options.yaml            # Strict Dart linting rules
└── pubspec.yaml                     # Workspace root manifest
```

## Directory Purposes

**`apps/swansport_app/lib/features/`:**
- Purpose: Feature-driven UI modules.
- Contains: 29 distinct domain features including `attendance`, `athlete_workspace`, `financial_management`, `social`, `training`, `turf`, `courts`.
- Key files: `app/widgets/swan_bottom_nav.dart`, `app/widgets/inbox_actions.dart`.

**`packages/swansport_data/lib/src/`:**
- Purpose: Shared data access layer for all frontends.
- Key files: `access.dart` (RBAC), `finance_service.dart`, `expense_service.dart`, `training_session_service.dart`, `court_service.dart`.

**`supabase/migrations/`:**
- Purpose: Single source of truth for database schema.
- Key files: `0001_foundation.sql` to `0076_athlete_account_link.sql`.

## Key File Locations

**Entry Points:**
- `apps/swansport_app/lib/main_development.dart`: Main app dev runner.
- `apps/swansport_app/lib/main_production.dart`: Main app production runner.
- `apps/swansport_console/lib/main.dart`: Desktop console web runner.

**Configuration:**
- `packages/swansport_core/lib/src/environment.dart`: Multi-tier environment config.
- `analysis_options.yaml`: Monorepo-wide linting and strict type analyzer settings.
- `melos.yaml`: Workspace task definitions.

## Naming Conventions

**Files:**
- Dart source files: `snake_case.dart`
- Dart test files: `*_test.dart`
- SQL migrations: `NNNN_descriptive_name.sql` (e.g. `0076_athlete_account_link.sql`)

**Classes & Types:**
- Classes: `PascalCase` (e.g., `SwanAccess`, `FinanceService`)
- Riverpod Providers: `camelCaseProvider` (e.g., `attendanceServiceProvider`)

## Where to Add New Code

**New UI Feature:**
- Place feature widget in `apps/swansport_app/lib/features/<feature_name>/presentation/`.
- Add test in `apps/swansport_app/test/<feature_name>_test.dart`.

**New Database Service / Query:**
- Place service class in `packages/swansport_data/lib/src/<feature>_service.dart`.
- Export from `packages/swansport_data/lib/swansport_data.dart`.

**New Database Schema / Migration:**
- Add next sequentially numbered file in `supabase/migrations/` (e.g. `0077_*.sql`).
- Test with `python tools/check_migrations.py`.

---

*Structure analysis: 2026-10-05*
