# Supabase Migrations

All database schema changes must be committed as SQL migration files. Do not create tables, indexes, functions, triggers, or policies manually in the Supabase dashboard without recording the same change here.

Use timestamped names such as `20260722090000_create_profiles.sql` when real migration work begins.

Sensitive tables must ship with matching Row Level Security policies in the same development task.
