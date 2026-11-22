-- The owner/admin SELECT policy already limits rows, but the authenticated
-- role lost the underlying table privilege. PostgREST therefore rejected the
-- App's insert(...).select('id') before RLS could evaluate the owner policy.
grant select on table public.profile_credentials to authenticated;
revoke select on table public.profile_credentials from anon;
