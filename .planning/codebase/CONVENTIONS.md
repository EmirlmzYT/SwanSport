# Coding Conventions

**Analysis Date:** 2026-10-05

## Naming Patterns

**Files:**
- `snake_case.dart` for all Dart source files.
- Tests must end in `_test.dart`.

**Classes & Enums:**
- `PascalCase` for classes, mixins, and enums.
- Enums in SQL match PostgreSQL conventions (e.g. `attendance_status`, `invoice_status`).

**Functions & Variables:**
- `camelCase` for methods, local variables, and provider declarations.
- Private members must be prefixed with `_`.

## Code Style

**Formatting:**
- Dart standard formatter (`dart format --line-length 80`).
- Validated via `melos run format:check`.

**Linting:**
- Root `analysis_options.yaml` with `package:lints/recommended.yaml`.
- Enforces `strict-casts`, `strict-inference`, and `strict-raw-types`.
- Strict rules: `prefer_const_constructors`, `prefer_final_locals`, `avoid_dynamic_calls`, `unawaited_futures`.

## Import Organization

**Order:**
1. Dart core libraries (`dart:async`, `dart:convert`)
2. Flutter framework packages (`package:flutter/...`)
3. Third-party packages (`package:flutter_riverpod/...`, `package:supabase_flutter/...`)
4. Internal workspace packages (`package:swansport_data/...`, `package:swansport_core/...`)
5. Relative project imports (discouraged; absolute package imports preferred via `prefer_relative_imports: false`)

## Design Tokens & UI Guidelines

**Typography:**
- Use `SwanType` steps (e.g. `SwanType.caption(...)`, `SwanType.titleLarge(...)`).
- Raw `TextStyle` calls with arbitrary font sizes (e.g., `jakarta(11.5)`) are forbidden.

**Palette:**
- Use `SwanPalette` tokens based on `isDark ? SwanPalette.dark : SwanPalette.light`.
- Pure black (`#000000`) is prohibited in dark theme — navy/charcoal is standard.
- `accent` (teal) is reserved for primary actions and active states only.

## Error Handling

**Data Layer:**
- Catch PostgREST errors and map to typed failure objects.
- Never swallow exceptions silently; provide user-friendly error state via Riverpod `AsyncValue`.

**Database:**
- Use `coalesce(..., false)` in check constraints to prevent null check escapes.
- Use explicit casts in safe order to prevent `42P13` or invalid JSON casts.

---

*Convention analysis: 2026-10-05*
