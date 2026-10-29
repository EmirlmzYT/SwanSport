# SwanSport Pro Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Every implementation task follows red-green-refactor and must be committed separately.

**Goal:** Move club and coaching operations into a shared Flutter feature package consumed by both SwanSport and SwanSport Pro, without removing any SwanSport route or changing its Ana Sayfa.

**Architecture:** A new `packages/swansport_pro_features` package owns reusable operation content, typed navigation/chrome ports, semantic visual tokens, context reset, and dirty-state coordination. `swansport_app` and `swansport_pro` provide thin host adapters. Existing `swansport_data` providers and database RLS/RPC remain the sole data and authorization layer; the package never talks to Supabase directly.

**Tech Stack:** Flutter 3.47.7, Dart 3.5+, Riverpod 2.6, GoRouter 14.8 in Pro, legacy/bridge Navigator in SwanSport, Supabase via `swansport_data`, `swansport_branch_engine`, `qr_flutter`, Python/Flutter/Node contract tests, GitHub Actions.

**Specs:**

- `docs/superpowers/specs/2026-10-26-swansport-pro-app-design.md`
- `docs/superpowers/specs/2026-10-26-swansport-pro-phase-2-design.md`

## Global Constraints

- Do not remove a route, menu entry, deep link, or operation from `apps/swansport_app` during Phase 2.
- Do not visually change SwanSport Ana Sayfa (`/akis`) or its social navigation shell.
- Use the existing production Supabase project and Auth pool. Do not create or copy a database or user account.
- Never duplicate authorization logic. Workspace visibility comes from `SwanAccess`; operation authority remains in existing RLS/RPC.
- Widgets do not call Supabase. Data reads/writes and Riverpod providers remain in `packages/swansport_data/lib/src/`.
- Preserve accountant privacy: the shared package must not expose athlete identity through accounting paths.
- Preserve unlinked athletes: `athletes.profile_id` remains nullable.
- Preserve all existing route argument and notification/deep-link contracts in SwanSport.
- Feature flags are visibility/rollout controls, not security. Every new flag must exist in SQL, Dart, sync tests, FAQ, and real host gates.
- Run Flutter commands from the owning package/app directory and run SDK checks sequentially in this OneDrive/WSL checkout.
- Each task ends in its own commit. Push after each accepted vertical slice, not after every experimental edit.

## Acceptance Order

1. Foundation and package boundary.
2. Slice A: team directory plus live/history attendance in both hosts.
3. Slice B: team roster detail in both hosts.
4. Slice C: training flows in both hosts.
5. Slice D: club panel and real Pro task entries.
6. Full regression, builds, package evidence, and device/UAT handoff.

Do not start a later slice until the current slice's tests and both-host parity checks pass.

---

### Task 1: Scaffold the shared operations package and enforce dependency boundaries

**Files:**

- Create: `packages/swansport_pro_features/pubspec.yaml`
- Create: `packages/swansport_pro_features/lib/swansport_pro_features.dart`
- Create: `packages/swansport_pro_features/lib/src/host/pro_feature_host.dart`
- Create: `packages/swansport_pro_features/lib/src/host/pro_feature_theme.dart`
- Create: `packages/swansport_pro_features/test/package_boundary_test.dart`
- Create: `tools/pro_features_contract_test.py`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `apps/swansport_app/pubspec.yaml`
- Modify: `apps/swansport_pro/pubspec.yaml`

**Interfaces:**

- `abstract interface class ProFeatureNavigator`
- `abstract interface class ProFeatureChrome`
- `final class ProFeatureThemeData` with `background`, `surface`, `line`, `ink`, `inkMuted`, `accent`, `danger`, `warning`, `success`
- `ProFeatureHostScope` exposes navigator, chrome, and semantic theme to descendants

- [ ] **Step 1: Write the failing source-contract test**

In `tools/pro_features_contract_test.py`, assert that the workspace contains the package exactly once; the package depends only on Flutter, Riverpod, `swansport_core`, `swansport_data`, `swansport_models`, `swansport_branch_engine`, and `qr_flutter`; and files below `packages/swansport_pro_features/lib` contain no imports from either application, app-specific route strings, `Supabase.instance`, `.from(`, `.rpc(`, or `.auth.`.

- [ ] **Step 2: Verify RED**

Run: `python -m unittest tools.pro_features_contract_test -v`

Expected: FAIL because the package does not exist.

- [ ] **Step 3: Create the minimal package and host contracts**

Add the package to root `workspace:` and both app pubspecs. Keep `ProFeatureNavigator` typed: methods for teams, roster `{teamId, teamName}`, attendance, attendance history, training list/protocol/builder/session/result, optional calendar, athlete profile, and optional conversation. Do not expose raw route strings through the package API.

`ProFeatureChrome` builds a host-owned page shell and reports safe snackbars/dialogs. The shared package supplies content and semantic intent; it does not own either app's bottom navigation.

- [ ] **Step 4: Add contract-level Dart tests**

Test that `ProFeatureHostScope.of(context)` returns the installed adapters, missing scope fails with a clear assertion in debug, semantic colors are complete in light/dark fixtures, and unsupported optional destinations return false rather than throwing.

- [ ] **Step 5: Resolve and verify GREEN**

Run from repository root: `flutter pub get`

Run: `python -m unittest tools.pro_features_contract_test -v`

Run from `packages/swansport_pro_features`: `flutter test --no-pub`

Expected: all tests PASS.

- [ ] **Step 6: Commit**

Commit message: `feat(pro): scaffold shared operations package`

### Task 2: Add context reset, dirty-state coordination, and safe operation errors

**Files:**

- Create: `packages/swansport_pro_features/lib/src/host/pro_feature_context.dart`
- Create: `packages/swansport_pro_features/lib/src/host/pro_dirty_state.dart`
- Create: `packages/swansport_pro_features/lib/src/host/pro_feature_state.dart`
- Create: `packages/swansport_pro_features/test/pro_feature_context_test.dart`
- Create: `packages/swansport_pro_features/test/pro_dirty_state_test.dart`
- Modify: `packages/swansport_data/lib/src/` only if a missing safe error classifier must be shared
- Modify: `packages/swansport_data/lib/swansport_data.dart` only for that public export
- Test: `packages/swansport_data/test/operation_error_test.dart` if the classifier is added

**Interfaces:**

- `ProFeatureContextKey(userId, workspace, clubId)`
- `proFeatureContextProvider`
- `ProDirtyStateCoordinator` with register/unregister, `isDirty`, and guarded transition
- `invalidateProFeatureState(WidgetRef ref)` containing an explicit provider invalidation list

- [ ] **Step 1: Write failing context and dirty-state tests**

Test equality and key changes for user/workspace/club; old keyed subtrees are disposed; a clean transition proceeds immediately; a dirty transition asks once; cancel preserves context/state; confirm clears dirty state, invalidates the listed providers, then switches context. Test registration disposal so a removed attendance screen cannot keep the whole app dirty.

- [ ] **Step 2: Verify RED**

Run from `packages/swansport_pro_features`:

`flutter test test/pro_feature_context_test.dart test/pro_dirty_state_test.dart --no-pub`

Expected: FAIL because the types do not exist.

- [ ] **Step 3: Implement the minimal coordinator and reset boundary**

Use an explicit immutable context value and a keyed subtree. Do not rely on `IndexedStack` disposal. Keep the invalidation list visible and testable; include only providers whose state is scoped to account, workspace, club, roster, attendance, or training.

- [ ] **Step 4: Introduce safe error classification only if current data APIs lack it**

First test existing provider errors. If raw PostgREST messages can reach widgets, add a small data-layer mapper with stable categories (`network`, `unauthorized`, `conflict`, `validation`, `unknown`) and user-safe Turkish messages. Preserve the original exception for diagnostics, not UI. Do not move Supabase types into the feature package.

- [ ] **Step 5: Verify GREEN**

Run the focused feature tests and any new `swansport_data` test. Then run:

`flutter test --no-pub` from `packages/swansport_pro_features`.

- [ ] **Step 6: Commit**

Commit message: `feat(pro): guard operation context transitions`

### Task 3: Add the Phase 2 feature-flag contract

**Files:**

- Create: `supabase/migrations/0135_pro_phase2_attendance_operations.sql`
- Modify: `packages/swansport_data/lib/src/feature_flags.dart`
- Modify: `packages/swansport_data/test/feature_flags_test.dart`
- Modify: `packages/swansport_data/test/feature_flag_sync_test.dart` only if its parser needs the new migration path
- Create: `tools/pro_phase2_flags_sql_test.mjs`

**Required behavior:**

- `attendance_operations` is inserted idempotently with audience `everyone`.
- Existing values remain unchanged: `offline_attendance=off`, `coach_workspace=admins`, `sport_training_sessions=admins`.
- An FAQ entry explains the online attendance operation and points to `/attendance`.
- No RLS/RPC authority is granted or weakened by this migration.

- [ ] **Step 1: Write the failing SQL and Dart contract tests**

Assert idempotence, the exact audience values above, the FAQ row, and the Dart constant `FeatureFlags.attendanceOperations == 'attendance_operations'`.

- [ ] **Step 2: Verify RED**

Run: `node --test tools/pro_phase2_flags_sql_test.mjs`

Run from `packages/swansport_data`: `flutter test test/feature_flags_test.dart test/feature_flag_sync_test.dart --no-pub`

Expected: FAIL because the flag and migration do not exist.

- [ ] **Step 3: Implement the migration and constant**

Use `insert ... on conflict` without changing existing flag audiences. Add only the FAQ/flag rows needed for Phase 2. Do not deploy the migration from this task.

- [ ] **Step 4: Verify GREEN**

Re-run the SQL and Dart tests. Also run existing general availability SQL tests to prove existing audiences are unchanged.

- [ ] **Step 5: Commit**

Commit message: `feat(pro): define phase two rollout flags`

### Task 4: Extract the team directory into the shared package

**Files:**

- Create: `packages/swansport_pro_features/lib/src/roster/team_directory_screen.dart`
- Create: `packages/swansport_pro_features/lib/src/roster/team_directory_content.dart`
- Create: `packages/swansport_pro_features/test/team_directory_test.dart`
- Create: `apps/swansport_app/lib/features/pro_operations/swan_pro_feature_host.dart`
- Modify: `apps/swansport_app/lib/features/teams/presentation/screens/team_roster_directory_screen.dart`
- Modify: `apps/swansport_app/lib/app/swansport_app.dart`
- Test: `apps/swansport_app/test/pro_team_directory_host_test.dart`

**Interfaces:**

- `SharedTeamDirectoryScreen`
- `ProFeatureNavigator.openRoster(TeamRouteTarget target)`
- `TeamRouteTarget(teamId, teamName)`

- [ ] **Step 1: Write failing shared widget tests**

Override `activeClubProvider`, `teamsProvider`, and the write service/provider used by the existing create-team sheet. Assert loading, safe error, empty, search, filters, manager-only create action, and typed roster navigation. Assert `FeatureFlags.teamHub` gates the shared entry.

- [ ] **Step 2: Verify RED**

Run from `packages/swansport_pro_features`: `flutter test test/team_directory_test.dart --no-pub`

- [ ] **Step 3: Move presentation behavior without copying data logic**

Port the existing directory UI into the package using semantic tokens and shared providers. Replace `SwanScaffold`, app design imports, premium helpers, bottom nav, and named navigation with host ports. Preserve exact provider/service behavior and do not rewrite queries.

- [ ] **Step 4: Replace SwanSport implementation with a thin host adapter**

Keep the class name and `/teams` route. The old file becomes a compatibility wrapper around the shared screen. Its navigator maps `TeamRouteTarget` back to `/takim-kadro` with the existing `{id, name}` argument map. Its chrome maps semantic tokens to `SwanPalette` and retains the existing SwanSport shell.

- [ ] **Step 5: Verify parity and route compatibility**

Test the same fixture through the package and SwanSport wrapper. Assert `/teams` still resolves, `/takim-kadro` receives the unchanged argument shape, and Ana Sayfa files have no diff.

Run the focused package/app tests, then `flutter analyze --no-pub` from both owning packages.

- [ ] **Step 6: Commit and push Slice A foundation**

Commit message: `feat(pro): share team directory`

### Task 5: Extract live attendance and attendance history

**Files:**

- Move/port to: `packages/swansport_pro_features/lib/src/attendance/attendance_workspace.dart`
- Move/port to: `packages/swansport_pro_features/lib/src/attendance/attendance_history_screen.dart`
- Move/port to: `packages/swansport_pro_features/lib/src/attendance/attendance_queue_banner.dart`
- Create: `packages/swansport_pro_features/test/live_attendance_test.dart`
- Create: `packages/swansport_pro_features/test/attendance_history_test.dart`
- Create: `packages/swansport_pro_features/test/attendance_dirty_guard_test.dart`
- Modify: `apps/swansport_app/lib/features/attendance/presentation/screens/live_attendance_screen.dart`
- Modify: `apps/swansport_app/lib/features/attendance/presentation/screens/attendance_workspace.dart`
- Modify: `apps/swansport_app/lib/features/attendance/presentation/screens/attendance_history_screen.dart`
- Modify: `apps/swansport_app/lib/features/attendance/presentation/attendance_queue_banner.dart`
- Test: `apps/swansport_app/test/pro_attendance_host_test.dart`

- [ ] **Step 1: Write failing attendance behavior tests**

Cover loading/error/empty/authorized states; team/athlete marking; save; optimistic-version conflict; uncertain operation retry with the same `op_id`; online gate `attendance_operations`; offline gate `offline_attendance`; and history filters. Test that no raw database exception appears in rendered text.

- [ ] **Step 2: Write failing dirty-transition tests**

Mark attendance without saving, then attempt back, club switch, workspace switch, and account switch. Assert the host confirmation appears and cancel/confirm behavior matches Task 2. A saved or pristine screen must not prompt.

- [ ] **Step 3: Verify RED**

Run the three focused package tests; expect missing shared widgets/behavior.

- [ ] **Step 4: Port the two separate screens**

Keep live attendance and history separate. Preserve the existing offline queue, server `op_id`, and conflict behavior from `swansport_data`. Replace named routes with `openAttendance`, `openAttendanceHistory`, and optional `openCalendar`. Do not merge screens into tabs.

- [ ] **Step 5: Preserve SwanSport compatibility**

Keep `/attendance` and `/devam-durumu` route builders and forwarding files. Preserve the calendar action in SwanSport. Gate the shared online entry with `attendance_operations` and the offline affordance independently with `offline_attendance`.

- [ ] **Step 6: Verify Slice A GREEN**

Run:

- shared roster and attendance tests;
- SwanSport host/route/navigation tests;
- `packages/swansport_data` attendance and offline-attendance tests;
- 320 px width and 2.0 text-scale widget tests;
- analyze for shared package and SwanSport.

Confirm `git diff -- apps/swansport_app/lib/features/home apps/swansport_app/lib/features/social/presentation/screens/feed_screen.dart` is empty.

- [ ] **Step 7: Commit and push**

Commit message: `feat(pro): share attendance operations`

### Task 6: Add Pro club context and integrate Slice A

**Files:**

- Create: `apps/swansport_pro/lib/features/operations/pro_feature_host.dart`
- Create: `apps/swansport_pro/lib/features/operations/pro_club_context_selector.dart`
- Create: `apps/swansport_pro/lib/features/operations/pro_operations_gate.dart`
- Create: `apps/swansport_pro/lib/features/operations/pro_tasks_screen.dart`
- Modify: `apps/swansport_pro/lib/features/dashboard/pro_dashboard_screen.dart`
- Modify: `apps/swansport_pro/lib/app/pro_router.dart`
- Modify: `apps/swansport_pro/lib/shell/pro_shell.dart`
- Modify: `apps/swansport_pro/lib/workspaces/pro_workspace_switcher.dart`
- Test: `apps/swansport_pro/test/pro_club_context_test.dart`
- Test: `apps/swansport_pro/test/pro_operations_navigation_test.dart`
- Test: `apps/swansport_pro/test/pro_dirty_transition_test.dart`

- [ ] **Step 1: Write failing Pro context tests**

Test one club auto-selects; multiple authorized clubs show a selector; selection writes `selectedClubIdProvider`; unauthorized IDs cannot be selected; account/workspace change resets the selection; and an operations role without active club membership sees the explicit no-operation-access message.

- [ ] **Step 2: Write failing Pro navigation/flag tests**

For Club/Coaching workspaces, test that Panel and Tasks show team/attendance cards only when `coach_workspace`, `team_hub`, and `attendance_operations` gates allow them. Assert Pro calendar action is absent, existing Takvim/Gelen Kutusu placeholders remain, and no social route/import is introduced.

- [ ] **Step 3: Verify RED**

Run the three focused Pro tests.

- [ ] **Step 4: Implement the Pro host adapter and routes**

Map typed targets to Pro routes such as `/operasyon/takimlar`, `/operasyon/yoklama`, and `/operasyon/devam`. Add nested routes outside the five fixed branch roots so back returns to the correct Pro branch. Use the shared context key `(userId, workspace, clubId)`.

- [ ] **Step 5: Guard selectors with dirty state**

Workspace and club selection must call the coordinator before changing providers. On confirm, invalidate the explicit feature providers; on cancel, retain the old selection and UI.

- [ ] **Step 6: Verify Slice A in both hosts**

Run all shared package tests, SwanSport host tests, and Pro tests. Analyze both apps. Confirm no production DB mutation and no SwanSport feature removal.

- [ ] **Step 7: Commit and push**

Commit message: `feat(pro): open roster and attendance workflows`

### Task 7: Extract team roster detail as Slice B

**Files:**

- Create: `packages/swansport_pro_features/lib/src/roster/team_roster_screen.dart`
- Create: `packages/swansport_pro_features/lib/src/roster/official_team_rosters.dart`
- Create: `packages/swansport_pro_features/test/team_roster_test.dart`
- Modify: `apps/swansport_app/lib/features/teams/presentation/screens/team_roster_screen.dart`
- Modify: `apps/swansport_app/lib/features/teams/presentation/widgets/official_team_rosters.dart`
- Modify: `apps/swansport_app/lib/app/swansport_app.dart`
- Modify: `apps/swansport_pro/lib/app/pro_router.dart`
- Test: `apps/swansport_app/test/pro_team_roster_host_test.dart`
- Test: `apps/swansport_pro/test/pro_team_roster_host_test.dart`

- [ ] **Step 1: Write failing roster tests**

Cover valid/invalid `TeamRouteTarget`, list and empty states, add/link athlete, team change, remove behavior for linked and unlinked athletes, official roster projections, and action visibility for admin/coach/read-only accounts. Explicitly test that a null `profile_id` athlete remains visible and manageable through allowed flows.

- [ ] **Step 2: Verify RED**

Run the focused package test.

- [ ] **Step 3: Port roster UI through host contracts**

Keep social profile and conversation actions optional through the navigator. Pro hides unsupported social actions; SwanSport retains them. Do not expose athlete identity through an accounting workspace and do not infer permissions from profile role alone.

- [ ] **Step 4: Preserve route parity**

SwanSport continues to accept `/takim-kadro` with `{id, name}`. Pro uses the typed target and rejects empty IDs with a safe error screen. Both render the same roster fixture and authorization result.

- [ ] **Step 5: Verify and commit Slice B**

Run package/app/Pro focused tests, `swansport_data` club/access tests, and analyses.

Commit message: `feat(pro): share team roster operations`

### Task 8: Extract training workflows as Slice C

**Files:**

- Move/port: `apps/swansport_app/lib/features/training/presentation/my_training_screen.dart`
- Move/port: `apps/swansport_app/lib/features/training/presentation/protocol_list_screen.dart`
- Move/port: `apps/swansport_app/lib/features/training/presentation/workout_builder_screen.dart`
- Move/port: `apps/swansport_app/lib/features/training/presentation/session_screen.dart`
- Move/port: `apps/swansport_app/lib/features/training/presentation/session_result_screen.dart`
- Move/port relevant widgets from: `apps/swansport_app/lib/features/training/presentation/widgets/`
- Create targets under: `packages/swansport_pro_features/lib/src/training/`
- Create tests under: `packages/swansport_pro_features/test/training/`
- Modify: `apps/swansport_app/lib/app/swansport_app.dart`
- Modify: `apps/swansport_pro/lib/app/pro_router.dart`
- Test: `apps/swansport_app/test/pro_training_host_test.dart`
- Test: `apps/swansport_pro/test/pro_training_host_test.dart`

- [ ] **Step 1: Write failing pure/widget tests by workflow**

Separate tests for history/live-session resume, template list, builder validation, live session phase/set/timer state, result submission, and branch drill pads. Reuse `swansport_branch_engine`; do not duplicate score/archetype/metric calculations in UI tests.

- [ ] **Step 2: Verify RED for the first workflow only**

Start with training list/protocols. Run only those tests and confirm the shared types are missing.

- [ ] **Step 3: Port incrementally inside Slice C**

Port and green one workflow at a time in this order: list/protocols, builder, live session, result, branch widgets. Keep temporary state local but register any unsaved builder/session state with the dirty coordinator. A user/workspace/club change cannot carry the old draft forward.

- [ ] **Step 4: Preserve all SwanSport route contracts**

Keep `/antrenmanlarim`, `/antrenman-sablonlari`, `/antrenman-olustur`, `/antrenman-oturumu`, and `/antrenman-sonuc`. Translate existing argument maps to typed package targets at the adapter boundary. Do not change notification route strings.

- [ ] **Step 5: Add Pro training entries and gates**

Expose training from Club/Coaching Panel and Tasks only when `coach_workspace` and `sport_training_sessions` are enabled. Keep personal-athlete actions governed by existing RLS/provider behavior; a credential alone must not grant club operations.

- [ ] **Step 6: Verify Slice C**

Run shared training tests, both host tests, `swansport_branch_engine` tests, `swansport_data` training tests, route/navigation regressions, 320 px/2.0 text-scale tests, and analyses.

- [ ] **Step 7: Commit and push**

Commit message: `feat(pro): share training workflows`

### Task 9: Extract the Phase 2 club operations panel as Slice D

**Files:**

- Create: `packages/swansport_pro_features/lib/src/club/club_operations_panel.dart`
- Create: `packages/swansport_pro_features/lib/src/club/club_operation_card.dart`
- Create: `packages/swansport_pro_features/test/club_operations_panel_test.dart`
- Modify: `apps/swansport_app/lib/features/clubs/presentation/club_cockpit_screen.dart`
- Modify: `apps/swansport_pro/lib/features/dashboard/pro_dashboard_screen.dart`
- Modify: `apps/swansport_pro/lib/features/operations/pro_tasks_screen.dart`
- Test: `apps/swansport_app/test/pro_club_panel_host_test.dart`
- Test: `apps/swansport_pro/test/pro_club_panel_host_test.dart`

- [ ] **Step 1: Write failing panel tests**

Using shared fixtures, test real counts/states only, no fabricated metrics; cards for teams, roster, live attendance, attendance history, training templates/session; and explicit no-active-club/no-operation-authority states. Test every card's required flag and access condition.

- [ ] **Step 2: Verify RED**

Run the shared panel test.

- [ ] **Step 3: Extract only Phase 2 sections**

Do not copy the full 2,072-line cockpit. Build small shared operation summary/card sections from existing providers. Federation, referee, finance, facility, health, platform, and later-phase cards stay in SwanSport or remain Pro placeholders according to the top-level design.

- [ ] **Step 4: Integrate both hosts**

SwanSport keeps its existing `/kulup-yonetim` shell and non-Phase-2 sections, embedding the shared Phase 2 block. Pro Panel embeds only the shared block for Club/Coaching contexts. Pro Tasks shows only actionable roster/attendance/training items backed by real providers.

- [ ] **Step 5: Verify Slice D and no-home-change invariant**

Run shared and both-host tests, access tests, flag sync tests, navigation tests, and analyses. Confirm Ana Sayfa source and golden/snapshot evidence are unchanged from the Phase 2 base commit.

- [ ] **Step 6: Commit and push**

Commit message: `feat(pro): share club operations panel`

### Task 10: Run full acceptance, builds, evidence, and downloadable previews

**Files:**

- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/build_pro_production_preview.yml`
- Modify: `tools/pro_app_contract_test.py`
- Modify: `tools/pro_features_contract_test.py`
- Create: `docs/swansport-pro-phase-2-verification.md`
- Modify: `docs/release-status.md`
- Modify: `.ai-team/TEAM_BOARD.md`
- Modify version in: `apps/swansport_pro/pubspec.yaml`

- [ ] **Step 1: Add CI contract expectations before workflow edits**

Tests must require shared-package analyze/tests, both host parity tests, source-boundary test, flags SQL/Dart sync, and Pro production APK/web/unsigned-iOS build jobs. Production-target verification must still require the exact production Supabase ref and must not print secrets.

- [ ] **Step 2: Run the complete local verification matrix**

Sequentially run:

1. Python source-contract suites.
2. Node SQL contract suites.
3. `dart format --output=none --set-exit-if-changed` on only changed Dart paths.
4. `flutter analyze --no-pub` for `swansport_data`, `swansport_pro_features`, `swansport_app`, and `swansport_pro`.
5. Full tests for `swansport_data`, `swansport_branch_engine`, `swansport_pro_features`, `swansport_app`, and `swansport_pro`.
6. SwanSport web/Android regression builds required by existing CI.
7. Pro production web, Android APK, and unsigned iOS builds with the guarded production environment.

Do not label Flutter validation passed if the SDK or platform toolchain was unavailable.

- [ ] **Step 3: Record four separate evidence classes**

In `docs/swansport-pro-phase-2-verification.md`, separate:

- implemented code;
- locally verified tests/builds;
- database deployment/CI/release state;
- physical device and role-based UAT evidence.

Do not call Phase 2 complete if production migration deployment or device/UAT is still outstanding.

- [ ] **Step 4: Version and build previews**

Bump Pro to the next patch/build number. Trigger the production preview workflow. Verify artifact integrity, package/bundle ID `com.swansport.pro`, display name, version, exact production URL, absence of staging URL, and absence of Firebase plist in unsigned iOS preview.

- [ ] **Step 5: Perform role-based UAT**

Using real authorized test accounts, cover: club admin, active club coach, credential-only coach, multi-club operator, multi-workspace operator, no-Pro-access account, offline attendance enabled/disabled, dirty transition cancel/confirm, and account switch. Record device/OS and observed results without storing credentials.

- [ ] **Step 6: Create downloadable release assets**

Only after successful CI and package inspection, publish APK and unsigned IPA assets with SHA-256 hashes and direct links. State clearly that unsigned IPA is not an installable App Store/TestFlight release and that signed iOS delivery still needs Apple signing/APNs/Firebase configuration when push is introduced.

- [ ] **Step 7: Final commit and push**

Commit message: `docs(pro): verify phase two operations`

## Definition of Done

Phase 2 is complete only when:

- all four vertical slices are shared by SwanSport and SwanSport Pro;
- SwanSport retains every original route/entry and Ana Sayfa appearance;
- Pro supports authorized club selection and real roster, attendance, and training workflows;
- dirty attendance/training state cannot silently cross account/workspace/club boundaries;
- access and feature-flag tests prove no authority expansion;
- local, CI, package, deployment, and device/UAT evidence are reported separately;
- production Auth remains the same shared user pool;
- downloadable Android and iOS preview artifacts are independently inspected.
