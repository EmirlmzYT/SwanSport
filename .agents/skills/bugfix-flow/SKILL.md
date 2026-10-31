---
name: bugfix-flow
description: Diagnose and fix a focused SwanSport defect with evidence, a minimal patch, and regression verification.
---

# Bug-fix flow

1. Reproduce or trace the reported behavior before editing; record the route, role, provider, RPC, or migration involved.
2. Search `apps/`, `packages/`, and `supabase/migrations/` for the existing implementation and tests.
3. State the suspected cause and smallest safe fix; ask if a material product decision is missing.
4. Add or update a focused regression test before broad changes where practical.
5. Patch only the owning layer; do not solve a database authorization defect by hiding UI.
6. Preserve `SwanAccess`, RLS, legacy routes, and existing public behavior.
7. Run the narrow test, then affected-package analyze/test and `git diff --check`.
8. If a check fails, fix it within scope and rerun it before reporting.
