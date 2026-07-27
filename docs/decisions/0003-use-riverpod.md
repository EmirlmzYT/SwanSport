# 0003 Use Riverpod

## Context

The Flutter app needs predictable state management with clear loading, data, and error states.

## Decision

Use `flutter_riverpod` without mandatory code generation in the first phase.

## Consequences

Widgets must depend on controllers/notifiers and providers. Supabase calls must stay behind repositories and services.
