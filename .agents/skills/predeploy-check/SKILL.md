---
name: predeploy-check
description: Validate SwanSport changes before a human-authorized release without deploying or connecting to production.
---

# Pre-deploy check

1. Read `docs/release-status.md` and list the affected app, package, backend, and release path.
2. Run `dart format --output=none --set-exit-if-changed <changed Dart paths>`.
3. In each affected Dart package, run `flutter analyze --no-pub --no-fatal-infos` and `flutter test --no-pub`.
4. For backend work, run `npm ci --prefix tools --ignore-scripts --no-audit --no-fund` and `npm test --prefix tools`.
5. For production web entrypoints, run `flutter build web --release --no-pub -t lib/main_production.dart --dart-define=APP_ENV=production --no-wasm-dry-run` from the affected app.
6. Run `git diff --check` and inspect the changed-file list for unrelated edits.
7. Fix in-scope failures, rerun failed checks, and report real output; never deploy or push migrations.
