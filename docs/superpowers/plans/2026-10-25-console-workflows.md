# Console daily workflows implementation plan

**Goal:** Complete the five console improvements the user delegated: consistent tables, contextual details, useful daily work, simpler forms, and remembered preferences.

**Architecture:** Keep the existing Flutter/Riverpod console and shared data services. Extend presentation components; reuse all server authorization and mutation paths. The previous workspace shell remains the common frame.

**Constraints:** No new database schema, production deployment, auth bypass or fake management data. Accountant finance projections remain anonymous. Local UI settings are account scoped, table settings also club scoped; no rows, selections, secrets or page offsets persist.

## Tasks

- [x] Shared tables and contextual details: retain server search/sort/pagination, add clear/reset and accessible row activation, right-side modal inspection for athletes and authorized federation matches. Preserve direct detail routes and list position. Prove panel close restores the list and keyboard works at 900/1200/1600 widths.
- [x] Preferences: add an overrideable browser preference store, safely restore workspace/theme/sidebar and athlete/ledger filters. Validate stored values, isolate accounts/clubs, survive unavailable storage and hydration races. Prove restoration and account changes in tests.
- [x] Daily work: use existing authorized finance/club/federation/referee sources to show prioritized actionable work, with explicit unavailable/empty states. Avoid invented deadlines and exposing club data in other workspaces. Test ordering, navigation and privacy.
- [x] Forms: introduce clear essential/optional sections and inline validation in expense and recurring training flows; preserve server authority, busy locking and entered values on error. Show success and prevent silent dismissal while saving. Test validation, optional-field retention and duplicate submission.
- [x] Finance integration: common toolbar and contextual read-only ledger detail; expense editing remains a separate explicit action. Retain anonymized counterpart data, filters and pagination; do not fake totals while data is loading/unavailable. Test list retention and income read-only behavior.
- [x] Integration: run all console tests, Flutter analysis and web build; review changes independently and refresh the existing localhost:55440 preview. Record actual verification and limitations.

## Review focus

Account changes during settings hydration; revoked role or unavailable workspace; filtered list remains mounted behind detail; empty/error totals are not zero; incomplete form stays editable after failure; no accidental write on detail inspection.

## Execution

Independent table, preference and daily-work files are assigned to separate agents; the primary agent owns forms and finance integration. Flutter commands run sequentially through the existing Windows SDK. No commits or deployment are part of this task.
