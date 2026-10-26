# SwanSport Pro Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independently installable SwanSport Pro Flutter application that uses the existing Supabase account and `SwanAccess`, exposes only authorized professional workspaces, and leaves SwanSport unchanged.

**Architecture:** `apps/swansport_pro` is a real workspace app with its own Android/iOS identity, bootstrap, router and presentation layer. It consumes `swansport_core`, `swansport_data` and `swansport_design_system`; it contains no operational feature migration and no Firebase dependency in Phase 1. A pure presentation mapper converts the shared `SwanAccess` result into Pro workspaces, while database RLS/RPC remains authoritative.

**Tech Stack:** Flutter 3.47.7, Dart 3.5+, Riverpod 2.6, GoRouter 14.8, Supabase Flutter 2.8, Material 3, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-26-swansport-pro-app-design.md`

## Global Constraints

- Do not remove or visually change anything in `apps/swansport_app`; its Ana Sayfa must remain untouched.
- Package identity is exactly `com.swansport.pro`; visible name is `SwanSport Pro`; initial version is `0.1.0+1`.
- Use the same Supabase URL/key and Auth user pool, but a separate local session per app; no silent cross-app SSO.
- Widgets never call Supabase directly; login/logout use `AccountSessionService` from `swansport_data`.
- Workspace visibility is derived from `SwanAccess`; it grants no authority beyond existing RLS/RPC.
- Phase 1 has no Firebase packages, push registration, operational feature screens, database migration or production deployment.
- `Panel` and `Hesap` are functional. `Görevler`, `Takvim` and `Gelen Kutusu` are explicit safe placeholders.
- Development may show a clear configuration screen; production must fail closed when Supabase configuration is absent or initialization fails.
- Generated or formatted files must be bounded to `apps/swansport_pro` and the exact root/CI/test files listed below.

## Review Focus

1. A credential-only coach sees only Antrenörlük, never Kulüp operations.
2. A multi-role account sees every authorized workspace once, in the fixed order, and selection resets if the account loses it.
3. Account/session changes cannot retain the previous user's selected workspace or visible profile data.
4. Missing production Supabase configuration shows an explicit failure and never fixture/sample data.
5. The unsigned iOS preview contains no `GoogleService-Info.plist`, Firebase plugin registration or push entitlement.

---

### Task 1: Create the independently identified Pro application

**Files:**
- Create: `apps/swansport_pro/**` using Flutter platform scaffolding for Android, iOS and web
- Create: `tools/pro_app_contract_test.py`
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

**Interfaces:**
- Consumes: workspace packages `swansport_core`, `swansport_data`, `swansport_design_system`
- Produces: workspace package `swansport_pro` with entrypoints `lib/main_development.dart` and `lib/main_production.dart`

- [ ] **Step 1: Write the failing source-contract test**

Create `tools/pro_app_contract_test.py` with unittest cases asserting:

- root `workspace:` contains `apps/swansport_pro` exactly once;
- Pro `pubspec.yaml` has `name: swansport_pro`, `version: 0.1.0+1`, workspace resolution, and only the required shared/runtime dependencies;
- Android namespace/application ID and every iOS Runner bundle ID equal `com.swansport.pro`;
- Android label and iOS display/bundle names equal `SwanSport Pro`;
- Pro source/pubspec/native projects contain neither `firebase_core`, `firebase_messaging`, `GoogleService-Info.plist` nor `aps-environment`.

- [ ] **Step 2: Run the contract test and verify RED**

Run: `python -m unittest tools.pro_app_contract_test -v`  
Expected: FAIL because `apps/swansport_pro` does not exist.

- [ ] **Step 3: Generate and narrow the application scaffold**

Run Flutter create for Android/iOS/web only, then set the exact identities above. Replace the generated sample counter code with minimal entrypoints. Add dependencies: Flutter/localizations, `flutter_riverpod`, `go_router`, `supabase_flutter`, and the three shared SwanSport packages. Do not add Firebase or copy source from `swansport_app`.

- [ ] **Step 4: Register the package and resolve the workspace**

Add `apps/swansport_pro` to root `workspace:` and run `flutter pub get` from the repository root to update the lockfile.

- [ ] **Step 5: Verify GREEN**

Run: `python -m unittest tools.pro_app_contract_test -v`  
Expected: all contract cases PASS.

- [ ] **Step 6: Commit**

Commit message: `feat(pro): scaffold separate application`

### Task 2: Implement the pure professional workspace resolver

**Files:**
- Create: `apps/swansport_pro/lib/workspaces/pro_workspace.dart`
- Create: `apps/swansport_pro/lib/workspaces/pro_workspace_controller.dart`
- Create: `apps/swansport_pro/test/pro_workspace_test.dart`
- Create: `apps/swansport_pro/test/pro_workspace_controller_test.dart`

**Interfaces:**
- Consumes: `SwanAccess` and `authSessionProvider` from `swansport_data`
- Produces: `enum ProWorkspace { club, coaching, federation, referee, accounting, facility, platform }`
- Produces: `List<ProWorkspace> proWorkspacesFor(SwanAccess access)` in the enum order above
- Produces: `selectedProWorkspaceProvider` whose value is either an available workspace or `null`

- [ ] **Step 1: Write failing resolver tests**

Test exact mappings:

- `SwanAccess.none` → empty;
- active `clubRole: 'club_admin'|'coach'|'official'` → Kulüp;
- `coachLevel > 0` without active staff membership → Antrenörlük but not Kulüp;
- active federation role/appointment → Federasyon;
- active referee → Hakemlik, inactive referee → none;
- non-empty accountant club IDs → Muhasebe;
- managed/delegated turf ID → Tesis;
- platform admin → Platform;
- a combined fixture returns all applicable values once in enum order.

Reuse constructor patterns from `packages/swansport_data/test/sports_roles_access_test.dart`; do not invent role semantics.

- [ ] **Step 2: Run resolver test and verify RED**

Run from `apps/swansport_pro`: `flutter test test/pro_workspace_test.dart --no-pub`  
Expected: FAIL because the resolver is absent.

- [ ] **Step 3: Implement the minimal pure mapper**

Use only these conditions from the approved spec: `hasActiveClubStaffMembership || hasOperationalClubRole`, `coachLevel > 0 || clubRole == 'coach'`, `canOpenFederationOperations`, `isReferee`, `isAccountant`, `canOpenTurfCenter`, `isPlatformAdmin`.

- [ ] **Step 4: Write and run selection/reset tests**

Test that the controller auto-selects the sole workspace, preserves a still-valid manual selection, resets to the first available workspace after an access/account change, and becomes null for no access. Override shared providers in a `ProviderContainer`; never add a second role calculator.

Run: `flutter test test/pro_workspace_test.dart test/pro_workspace_controller_test.dart --no-pub`  
Expected: PASS.

- [ ] **Step 5: Commit**

Commit message: `feat(pro): resolve authorized workspaces`

### Task 3: Add fail-closed bootstrap and shared-account authentication

**Files:**
- Create: `apps/swansport_pro/lib/app/pro_environment.dart`
- Create: `apps/swansport_pro/lib/app/pro_bootstrap.dart`
- Create: `apps/swansport_pro/lib/app/pro_app.dart`
- Create: `apps/swansport_pro/lib/features/auth/pro_auth_controller.dart`
- Create: `apps/swansport_pro/lib/features/auth/pro_auth_gate.dart`
- Create: `apps/swansport_pro/lib/features/auth/pro_login_screen.dart`
- Create: `apps/swansport_pro/lib/features/auth/pro_startup_failure_screen.dart`
- Modify: `apps/swansport_pro/lib/main_development.dart`
- Modify: `apps/swansport_pro/lib/main_production.dart`
- Test: `apps/swansport_pro/test/pro_bootstrap_test.dart`
- Test: `apps/swansport_pro/test/pro_auth_test.dart`

**Interfaces:**
- Consumes: `SupabaseConfig.fromCompileTime`, `supabaseConfigProvider`, `authSessionProvider`, `accountSessionServiceProvider`, `currentProfileProvider`, `swanAccessProvider`
- Produces: `Future<void> bootstrapPro(ProEnvironment environment, {SupabaseConfig config = SupabaseConfig.empty})`
- Produces: `ProAuthController.signIn(email, password)` and `signOut()` delegating to `AccountSessionService`

- [ ] **Step 1: Write failing bootstrap tests**

Inject the initialization boundary so tests can assert: configured startup installs the shared provider overrides; missing/failed production config renders `ProStartupFailureScreen`; no production path silently switches to fixtures; the app root is not wrapped in any push/Firebase lifecycle observer.

- [ ] **Step 2: Verify RED**

Run: `flutter test test/pro_bootstrap_test.dart --no-pub`  
Expected: FAIL because Pro bootstrap types are absent.

- [ ] **Step 3: Implement the minimal bootstrap**

Mirror only the safe Supabase key handling from the social bootstrap (`sb_publishable_` versus legacy anon key). Keep diagnostics, push, test-center and social deep-link code out. Production errors must be visible and retryable; log no credentials.

- [ ] **Step 4: Write failing auth widget/controller tests**

Assert loading, signed-out login, login validation/in-flight/error states, signed-in access resolution, roles-with-no-Pro-access screen, account logout, and a session-user change rebuilding account-scoped state. Verify widgets call the controller/service and contain no `.from(`, `.rpc(` or `.auth.` calls.

- [ ] **Step 5: Implement auth and verify GREEN**

Use `AccountSessionService` only. Key the authenticated subtree by session user ID and invalidate shared SwanAccess providers on auth transition before presenting the new account.

Run: `flutter test test/pro_bootstrap_test.dart test/pro_auth_test.dart --no-pub`  
Expected: PASS.

- [ ] **Step 6: Commit**

Commit message: `feat(pro): add shared account authentication`

### Task 4: Build the Pro shell, dashboard and safe placeholders

**Files:**
- Create: `apps/swansport_pro/lib/app/pro_router.dart`
- Create: `apps/swansport_pro/lib/app/pro_theme.dart`
- Create: `apps/swansport_pro/lib/shell/pro_shell.dart`
- Create: `apps/swansport_pro/lib/shell/pro_navigation.dart`
- Create: `apps/swansport_pro/lib/workspaces/pro_workspace_switcher.dart`
- Create: `apps/swansport_pro/lib/features/dashboard/pro_dashboard_screen.dart`
- Create: `apps/swansport_pro/lib/features/placeholders/pro_placeholder_screen.dart`
- Create: `apps/swansport_pro/lib/features/account/pro_account_screen.dart`
- Create: `apps/swansport_pro/test/pro_shell_test.dart`
- Create: `apps/swansport_pro/test/pro_accessibility_test.dart`

**Interfaces:**
- Consumes: `selectedProWorkspaceProvider`, `proWorkspacesFor`, shared profile/session providers and `SwanTheme`
- Produces: fixed routes `/panel`, `/gorevler`, `/takvim`, `/gelen-kutusu`, `/hesap`
- Produces: five fixed navigation destinations and a workspace switcher limited to authorized values

- [ ] **Step 1: Write failing shell tests**

Assert five destinations and exact labels; Panel/Hesap are functional; the other three show “yakında” and do not read notification/calendar providers; single workspace hides switching affordance; multi-workspace selection updates Panel; no-access route cannot be bypassed; logout returns to login; account change removes the old name/workspace in the next frame.

- [ ] **Step 2: Verify RED**

Run: `flutter test test/pro_shell_test.dart --no-pub`  
Expected: FAIL because the shell is absent.

- [ ] **Step 3: Implement the shell and visual system**

Use the shared Material 3 Swan theme as the base, with a restrained professional operations layout. Do not import `apps/swansport_app`, copy its social shell, or modify its Ana Sayfa. The dashboard may show only workspace identity and honest Phase 1 status/action cards—no fabricated counts. “SwanSport'u aç” uses a platform adapter; unsupported targets show a web/store fallback instead of failing.

- [ ] **Step 4: Add accessibility tests**

At text scale 2.0 and a 320 logical-pixel width, assert no overflow; navigation and switcher targets have semantic labels and at least 48×48 logical-pixel hit areas; keyboard traversal reaches all five destinations on web/desktop.

- [ ] **Step 5: Verify GREEN**

Run: `flutter test --no-pub` from `apps/swansport_pro`  
Expected: all Pro tests PASS.

- [ ] **Step 6: Commit**

Commit message: `feat(pro): add workspace shell`

### Task 5: Add CI/build gates and Phase 1 evidence

**Files:**
- Modify: `.github/workflows/ci.yml`
- Create: `.github/workflows/build_pro_preview.yml`
- Create: `docs/swansport-pro-phase-1-verification.md`
- Modify: `.ai-team/TEAM_BOARD.md`

**Interfaces:**
- Consumes: GitHub `staging` environment secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Produces: CI analyze/test/web build plus separately named Android APK and unsigned iOS IPA artifacts for SwanSport Pro

- [ ] **Step 1: Extend the contract test and verify RED**

Add assertions that CI includes `apps/swansport_pro`; web build matrix includes `swansport_pro`; preview workflow builds `apps/swansport_pro` with staging secrets, validates that the Supabase project is not production, and uploads distinct `SwanSport-Pro` artifacts. Assert the iOS packaging step runs `verify_ios_preview_bundle.py --firebase-enabled false` and the final app has no plist/push entitlement.

- [ ] **Step 2: Implement CI gates**

Add Pro to existing package-local analyze/test and web-build matrices. Create a manually dispatched preview workflow with Ubuntu Android and macOS unsigned-iOS jobs; do not deploy web, migrate SQL, tag a release, configure Firebase/APNs, or touch the existing SwanSport release workflows.

- [ ] **Step 3: Run local verification**

Run, in order:

1. `python -m unittest tools.pro_app_contract_test -v`
2. `flutter pub get --enforce-lockfile` from repository root
3. `dart format --output=none --set-exit-if-changed apps/swansport_pro/lib apps/swansport_pro/test`
4. `flutter analyze --no-pub --no-fatal-infos` from `apps/swansport_pro`
5. `flutter test --no-pub` from `apps/swansport_pro`
6. `flutter build web --release --no-pub -t lib/main_production.dart --dart-define=APP_ENV=production --no-wasm-dry-run` with non-production test configuration
7. Existing affected tests: `packages/swansport_data/test/access_test.dart` and the full existing CI matrix where available.

Expected: zero errors/failures. Formatting is bounded because this workspace can retain Windows file handles.

- [ ] **Step 4: Inspect the source boundary**

Run `git diff -- apps/swansport_app` and require empty output. Search Pro for Firebase/push references and require none except the negative contract test/documentation. Run `git diff --check`.

- [ ] **Step 5: Record honest evidence**

Document exact commands/results, generated artifact status, and explicit limits: no operational modules, push, signed IPA, production deployment or physical-device acceptance. Do not claim a workflow/artifact passed until GitHub reports success and the package is inspected.

- [ ] **Step 6: Commit**

Commit message: `ci(pro): verify phase one application`

## Self-Review Result

- Spec coverage: all Phase 1 requirements map to Tasks 1–5; later feature migration and push remain explicitly excluded.
- Step scan: each task has a red test, minimal implementation, green verification and commit boundary.
- Type consistency: workspace enum/resolver/controller names are stable across Tasks 2–4; auth uses the existing shared service.
- Review focus: all five risks have an owning test in Tasks 1–4.
- Proportion: platform scaffolding details are delegated to Flutter; the plan fixes identities, interfaces and acceptance behavior without transcribing implementation bodies.
