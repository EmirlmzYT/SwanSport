# Codebase Concerns

**Analysis Date:** 2026-10-05

## Tech Debt & Known Pitfalls (Documented in AGENTS.md)

**1. Athlete Account Linking (`athletes.profile_id`):**
- Issue: Historically, `athletes.profile_id` was nullable and not consistently populated upon member registration, separating roster entries from authentication accounts.
- Resolution: Migration `0076_athlete_account_link.sql` introduced `create_athlete_from_member` and `link_athlete_to_member`. Accountless athletes (e.g. young children) must remain supported.

**2. Feature Flag 5-Point Synchronization:**
- Issue: Feature flags exist across 5 locations (SQL migration, Dart constant, sync test, FAQ entry, and UI guard). Omitting any point causes silent failures.
- Mitigation: `feature_flag_sync_test.dart` and `tools/check_faq.py` validate synchrony before release.

**3. Database Lock Timeouts & Cron Deadlocks:**
- Issue: Long single-transaction migrations can deadlock (`40P01`) against active `pg_cron` jobs.
- Mitigation: Migrations must be run file-by-file with `set local lock_timeout = '15s'`.

## Security Considerations

**1. Accountant Privacy:**
- Accountants must never see athlete names or personal data. Financial queries use `acc_*` RPCs and deterministic pseudonym tokens (`athlete_ref`).

**2. RLS & Security Definer Grants:**
- Every new migration must explicitly revoke permissions from `PUBLIC` and grant only to `authenticated` or specific roles.

**3. Health Restrictions:**
- Health clearance cannot be toggled by regular club admins; only actively certified health officers (`is_authorized_health_officer`) may modify health restrictions.

## Fragile Areas

**1. PostgREST RPC Signatures:**
- Changing RPC return types requires `drop function if exists` prior to recreation to prevent PostgreSQL error `42P13`.
- Overloading parameters without dropping old functions causes PostgREST HTTP 300 Multiple Choices errors.

**2. Navigation Shell:**
- `SwanBottomNav` relies on current route inspection rather than external index state. Route renames must update route matcher logic.

---

*Concerns audit: 2026-10-05*
