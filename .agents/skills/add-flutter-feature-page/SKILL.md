---
name: add-flutter-feature-page
description: Add a SwanSport Flutter feature page or template while preserving routing, shared data access, and design-system boundaries.
---

# Add a Flutter feature page

1. Read `AGENTS.md`, the owning app README, and the nearest feature under `apps/swansport_app/lib/features/`.
2. Confirm the target is an app screen, not a CMS/news template; SwanSport has no news-page framework.
3. Reuse a route in `apps/swansport_app/lib/app/routing/` or add the route and its navigation-test entry together.
4. Put UI in the owning app; put queries, services, and providers in `packages/swansport_data/lib/src/`.
5. Reuse `SwanAccess`, design tokens, shared widgets, and an existing loading/error pattern.
6. Do not call Supabase from a widget or create a second data-access path.
7. Add the narrowest widget, route, or provider test in the affected package.
8. Run format, `flutter analyze --no-pub --no-fatal-infos`, and `flutter test --no-pub` from that package.
