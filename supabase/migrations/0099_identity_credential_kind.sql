-- Commit this migration before 0100: PostgreSQL cannot use a new enum value
-- in the transaction that adds it. No new credential/document table.
set local lock_timeout = '15s';
alter type public.credential_kind add value if not exists 'identity';
