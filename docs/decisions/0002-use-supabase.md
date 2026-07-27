# 0002 Use Supabase

## Context

SwanSport needs authentication, PostgreSQL, storage, server-side functions, and security policies.

## Decision

Use Supabase for backend, database, authentication, storage, and future Edge Functions.

## Consequences

Database changes must be migration-driven. RLS policies are a required part of secure feature delivery.
