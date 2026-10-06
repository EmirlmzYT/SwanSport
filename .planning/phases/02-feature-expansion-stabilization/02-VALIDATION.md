---
phase: "02"
slug: "feature-expansion-stabilization"
status: draft
nyquist_compliant: true
wave_0_complete: false
created: "2026-10-05"
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter Test / Riverpod Test |
| **Config file** | `apps/swansport_app/pubspec.yaml` |
| **Quick run command** | `flutter test apps/swansport_app/test/widgets/inbox_actions_test.dart` |
| **Full suite command** | `flutter test apps/swansport_app/test/navigation_test.dart apps/swansport_app/test/widgets/inbox_actions_test.dart` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test apps/swansport_app/test/widgets/inbox_actions_test.dart`
- **After every plan wave:** Run `flutter test apps/swansport_app/test/navigation_test.dart` & `flutter analyze apps/swansport_app`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | D-01, D-02 | — | N/A | widget | `flutter test apps/swansport_app/test/widgets/swan_top_bar_test.dart` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | D-02 | — | N/A | widget | `flutter test apps/swansport_app/test/widgets/inbox_actions_test.dart` | ✅ | ⬜ pending |
| 02-02-01 | 02 | 2 | D-03 | — | N/A | widget | `flutter test apps/swansport_app/test/navigation_test.dart` | ✅ | ⬜ pending |
| 02-02-02 | 02 | 2 | D-04 | — | N/A | analyze | `flutter analyze apps/swansport_app` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `apps/swansport_app/test/widgets/swan_top_bar_test.dart` — tests for SwanTopBar wordmark, actions, and back navigation

---

## Manual-Only Verifications

| Behavior | Why Manual | Verification Procedure |
|----------|------------|------------------------|
| Caveat script wordmark visual appeal | Font rendering & baseline balance | Run on Web/Android, inspect 'swanspor' script alignment and 2-icon spacing |
| Dark/Light mode card border appearance | Subtle opacity rendering | Toggle theme in app settings, confirm border line visibility on c.surface |
