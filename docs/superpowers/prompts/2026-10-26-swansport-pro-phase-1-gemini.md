# Gemini Worker Prompt — SwanSport Pro Phase 1

You are the implementation worker for SwanSport Pro Phase 1. The architecture,
scope and implementation plan were authored and approved by the supervising
Codex agent. Treat them as binding; do not redesign the product or broaden the
scope.

Repository root:
`/mnt/c/Users/anado/OneDrive/Documents/ChatGPT/swansport`

Read completely, in this order:

1. Repository `AGENTS.md` and `agents.md` instructions.
2. `docs/superpowers/specs/2026-10-26-swansport-pro-app-design.md`.
3. `docs/superpowers/plans/2026-10-26-swansport-pro-phase-1.md`.

Then implement the plan task-by-task using test-driven development. The final
code will be independently reviewed by the supervising Codex agent, so report
evidence rather than confidence.

Non-negotiable boundaries:

- Build a real separate Flutter app at `apps/swansport_pro` with Android/iOS
  ID `com.swansport.pro`, display name `SwanSport Pro`, version `0.1.0+1`.
- Do not modify, remove, reformat or visually change anything under
  `apps/swansport_app`; especially do not touch its Ana Sayfa.
- Use the same Supabase Auth/account through shared `swansport_core` and
  `swansport_data`. Do not create a second role calculator.
- Workspace visibility comes only from `SwanAccess`; database RLS/RPC remains
  the authority. UI hiding is not security.
- Widgets must not call Supabase. Use existing providers and
  `AccountSessionService`.
- Phase 1 has no operational feature migration, database migration, Firebase,
  push, production deploy, signed IPA or cross-app silent SSO.
- Panel and Hesap work. Gorevler, Takvim and Gelen Kutusu are honest safe
  placeholders and must not query their current social data sources.
- Production startup fails closed when Supabase configuration is missing or
  initialization fails. Never substitute fixtures in production.
- A credential-only coach gets Antrenorluk but not Kulup. Account changes must
  clear the prior account's workspace/profile state.
- Generate platform scaffolding only inside `apps/swansport_pro`. Use patch-based
  edits for hand-authored files, preserve unrelated/user changes, and never run
  destructive Git commands.
- Commit each completed task with the exact plan commit message. Do not push,
  deploy, migrate SQL, create releases or modify secrets; the supervisor owns
  review and final push.

Execution protocol:

1. Check `git status` and the team board before editing; stop if another writer
   owns overlapping files.
2. For every task, write the specified failing test and show the observed RED
   result before implementation.
3. Implement only enough to satisfy the task and approved design.
4. Run the task's GREEN commands from the package working directory.
5. Before every commit, run `git diff --check` and inspect the scoped diff.
6. At the end, run all Task 5 verification commands. `git diff --
   apps/swansport_app` must be empty.
7. Return: commits, files changed, exact test/build results, remaining limits,
   and any command that could not be run. Never claim a CI artifact or physical
   device result that was not observed.

If an instruction is ambiguous or implementing it would require changing
SwanSport, SQL, production infrastructure, Firebase/push, or the approved
scope, stop and report the blocker instead of guessing.
