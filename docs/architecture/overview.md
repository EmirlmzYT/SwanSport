# SwanSport Architecture Overview

SwanSport is a modular sports management platform built with Flutter for mobile and web clients, and Supabase for backend services.

The first MVP uses a single Flutter application in `apps/swansport_app`. Android, iOS, Web, and Windows are the initial target platforms. Admin features stay inside the same application at first, but shared packages keep the path open for a future `apps/swansport_admin` Flutter Web application.

The repository is a Dart workspace managed with Melos. Product code is split into the app and shared packages:

- `swansport_core` for app-agnostic infrastructure primitives.
- `swansport_models` for shared Dart model/value types.
- `swansport_design_system` for Material 3 based UI foundations and components.
- `swansport_branch_engine` for branch configuration contracts.

Application features follow a feature-first structure. Each feature can grow presentation, application, domain, and data layers when needed. Small features should not carry empty layers before they have real responsibility.

State management uses Riverpod. Widgets should talk to controllers or notifiers, not directly to Supabase. The expected flow is:

```text
UI -> Controller/Notifier -> Repository -> Service -> Supabase
```

Database schema, indexes, functions, triggers, seed data, and RLS policies will be managed through the `supabase/` directory. Manual dashboard-only database changes are not part of the development process.
