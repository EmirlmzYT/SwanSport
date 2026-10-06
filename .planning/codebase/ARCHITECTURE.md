<!-- refreshed: 2026-10-05 -->
# Architecture

**Analysis Date:** 2026-10-05

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                       Presentation Layer                    │
├──────────────────────────────┬──────────────────────────────┤
│    `apps/swansport_app`      │   `apps/swansport_console`   │
│   (Mobile & Web Social App)  │   (Desktop Web Admin Panel)  │
└──────────────┬───────────────┴──────────────┬───────────────┘
               │                              │
               ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Shared UI & Design System                │
│             `packages/swansport_design_system`              │
│       (Theme, SwanType, SwanPalette, Mobile Widgets)        │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Shared Data Layer                       │
│                 `packages/swansport_data`                   │
│      (Riverpod Providers, Supabase Services, SwanAccess)    │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────────┐┌─────────────────────────────┐
│  `packages/swansport_core`   ││`swansport_branch_engine`    │
│  (Config, Environment, Types)││(Branch Rules, Sport Engines)│
└──────────────┬───────────────┘└─────────────┬───────────────┘
               │                              │
               └──────────────┬───────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Supabase Backend                        │
│          (PostgreSQL 15, 76 Migrations, RLS, RPCs)          │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `swansport_app` | Mobile and web player/coach/parent interface | `apps/swansport_app/` |
| `swansport_console` | Desktop administrative operations (>=900px) | `apps/swansport_console/` |
| `swansport_data` | Single source of truth for Supabase queries & Riverpod state | `packages/swansport_data/` |
| `swansport_design_system` | Design tokens, color palette, typography, core UI | `packages/swansport_design_system/` |
| `swansport_core` | App environment, base contracts, shared constants | `packages/swansport_core/` |
| `swansport_branch_engine` | Pure Dart training logic, scoring, and sport branch rules | `packages/swansport_branch_engine/` |
| `supabase/migrations` | Authoritative database schema, RLS policies, RPCs | `supabase/migrations/` |

## Pattern Overview

**Overall:** Layered Clean Architecture with Riverpod Reactive State Management.

**Key Invariants (from AGENTS.md):**
- **No direct Supabase calls in UI widgets:** All database interaction must route through `swansport_data` services and Riverpod providers.
- **`swansport_data` never imports UI:** No `IconData`, `Color`, or Flutter widget dependencies inside data packages.
- **Centralized authorization in `SwanAccess`:** Permissions are calculated in `packages/swansport_data/lib/src/access.dart` and shared by both mobile and console apps.
- **Security in database, not UI:** UI concealment is never relied upon for security; all authorization is strictly enforced by PostgreSQL RLS and security definer functions.

## Layers

**Presentation Layer:**
- Location: `apps/swansport_app/lib/features/` and `apps/swansport_console/lib/`
- Contains: Screen widgets, controllers, bottom navigation, and form state.
- Depends on: `swansport_data`, `swansport_design_system`, `flutter_riverpod`.

**Data Layer:**
- Location: `packages/swansport_data/lib/src/`
- Contains: `*Service` classes (e.g. `FinanceService`, `AttendanceService`), Riverpod providers, models.
- Depends on: `supabase_flutter`, `swansport_core`, `swansport_models`.

**Domain / Engine Layer:**
- Location: `packages/swansport_branch_engine/`
- Contains: Pure Dart sport rules, session phases, score validators. Zero framework dependencies.

## Data Flow

### Primary Request Path (Mobile / Console -> Supabase)

1. User interaction triggers Riverpod provider action in UI (`apps/swansport_app/lib/features/...`).
2. Controller invokes method on `swansport_data` service (`packages/swansport_data/lib/src/...`).
3. Service calls PostgreSQL RPC or PostgREST table with authentication context.
4. Supabase validates RLS policies and role verification in database.
5. Reactive stream or Future updates Riverpod state, updating UI declaratively.

### Authorization Flow

1. User authenticates via Supabase Auth (`auth.uid()`).
2. `SwanAccess` reads `profiles`, `club_memberships`, and approved `profile_credentials`.
3. In-memory permission matrix resolves available routes and modules.
4. Server RPCs independently enforce identical permission checks via `auth.uid()`.

## Architectural Constraints

- **Accountant Privacy:** Accountants cannot access `athletes` table directly. Financial RPCs (`acc_*`) mask athlete names using deterministic hash identifiers (`#A3F91C`).
- **Offline Attendance Conflict Resolution:** Optimistic versioning with server-side `attendance_op_logs` and `(actor_id, op_id)` idempotency.
- **Health Restrictions Gate:** Health blocks cannot be overridden by club admins; only authorized medical officers (`is_authorized_health_officer`) can lift medical restrictions.

---

*Architecture analysis: 2026-10-05*
