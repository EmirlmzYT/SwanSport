# Flutter and Dart style

- Use Dart null safety and the repository's strict analyzer settings.
- Copy the nearby style: explicit return types, `final`, trailing commas, and ordered imports.
- Use Riverpod providers and existing service APIs; do not call Supabase from a widget.
- Reuse design-system tokens and shared widgets; do not add arbitrary colors, sizes, or duplicate components.
- Use the current Flutter, Riverpod, GoRouter, and Supabase APIs from local code, not memory.
- Do not use deprecated syntax or guess a package API; inspect the installed dependency and local examples.
- Keep changes narrow; do not rewrite a whole screen, router, or provider for a small fix.
- Run package-local analyze, tests, and format checks after Dart changes.
