# Package Boundaries

## swansport_core

Contains environment primitives, result types, shared failures, logger contracts, validation helpers, and future date/time utilities.

It must not contain Flutter widgets, feature-specific business logic, Supabase query code, or product screens.

## swansport_models

Contains shared Dart models, identifiers, enums, pagination types, and value objects.

It must not depend on Flutter, Supabase clients, Riverpod, or the main app.

## swansport_design_system

Contains Material 3 based SwanSport themes, tokens, shared components, and responsive UI foundations.

It may depend on Flutter. It must not contain feature business rules, repositories, Supabase access, or app-specific navigation.

## swansport_branch_engine

Contains branch engine contracts, field schema definitions, scoring configuration contracts, and organization type definitions.

It must remain a pure Dart package and must not hard-code real sports before those requirements are approved.

## Dependency direction

```text
swansport_app
  -> swansport_core
  -> swansport_design_system
  -> swansport_models
  -> swansport_branch_engine
```

Shared packages must not depend on `swansport_app`. Cyclic dependencies are not allowed.
