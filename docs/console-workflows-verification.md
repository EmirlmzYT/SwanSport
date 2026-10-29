# Console workflow revision — 2026-10-25

## Delivered behavior

- Shared table toolbar with synchronized search clearing, reset, CSV busy/error handling, keyboard row activation and retry states. Ledger deliberately hides search because its RPC does not support it.
- Right-side modal inspection for athletes, ledger entries and provincial matches. Closing retains the list route, query and scroll state; direct athlete detail URLs remain available. Ledger inspection itself performs no write; income has no expense editing action.
- Prioritized club/accountant work list uses existing finance/club queues. Only attendance is explicitly today scoped; aggregate queues are labeled accordingly. Referee home reads real assignments, with unavailable/empty states. Federation retains its existing real command center.
- Expense and recurring-training forms foreground essential fields, preserve collapsed optional input, validate inline, block duplicate submissions/dismissal while saving and report successful completion. Ledger totals remain unavailable while loading or after failure rather than falling back to zero.
- Browser preferences restore theme, workspace, sidebar and athlete/ledger view filters. Keys are account scoped and table filters additionally club scoped. Rows, selections, credentials and page offsets are not persisted. Malformed or unavailable storage falls back safely.
- Account switching recreates the entire account-owned provider/navigation container; token refresh updates auth in the existing container. Old club and row caches do not cross account boundaries.

## Verification

- Windows Flutter console suite: **107 tests passed**.
- Flutter analysis: **0 errors, 1 existing warning**, plus style/deprecation information. This is not a clean-lint claim.
- Independent read-only review found no actionable important regressions in auth isolation, anonymous accountant data, navigation, panels or forms.
- Loopback server checks: `/`, `/sporcular`, `/defter`, `/il-ligleri` return HTTP 200 with `Cache-Control: no-store`.
- Final release web build succeeded: `build/local-console` (75.2 seconds). Detailed local output: `apps/swansport_console/build/workflows-build.log` (ignored artifact).

## Runtime boundary

The preview at `http://localhost:55440` is the real authenticated console,
using the Supabase environment selected at build time. There is no fixture
fallback or auth bypass. No SQL migration, production deployment or live data
mutation was performed for this UI revision. Tests use isolated synthetic
provider overrides; authenticated browser acceptance with each real role is
separate from widget tests and compilation.
