# Architecture

- Edit the owning application or package; do not put code in a similarly named folder by guesswork.
- Read the package README and nearest existing implementation before adding a file.
- Put shared data access in `packages/swansport_data/lib/src/`.
- Keep `swansport_data` free of widgets, `Color`, `IconData`, and themes.
- Put presentation-only constants in the consuming app's `presentation/` directory.
- Use `SwanAccess` for permission-derived UI; do not recalculate roles in an app.
- Add routes through the existing router and route metadata; preserve legacy deep links.
- Do not invent a service, provider, RPC, model field, or route; search first.
- Do not refactor adjacent architecture unless the task explicitly requests it.
