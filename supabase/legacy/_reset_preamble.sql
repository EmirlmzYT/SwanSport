-- ============================================================
-- RESET — drops SwanSport objects so the script is re-runnable.
-- Safe on a fresh project (no real data yet). Remove this block
-- once the schema is stable and you rely on incremental migrations.
-- ============================================================

drop trigger if exists on_auth_user_created on auth.users;

drop table if exists public.guardians        cascade;
drop table if exists public.team_memberships cascade;
drop table if exists public.athletes         cascade;
drop table if exists public.club_memberships cascade;
drop table if exists public.teams            cascade;
drop table if exists public.seasons          cascade;
drop table if exists public.clubs            cascade;
drop table if exists public.profiles         cascade;

drop function if exists public.create_club(text, text, text) cascade;
drop function if exists public.is_guardian_of(uuid)          cascade;
drop function if exists public.is_club_admin(uuid)           cascade;
drop function if exists public.is_club_staff(uuid)           cascade;
drop function if exists public.is_club_member(uuid)          cascade;
drop function if exists public.handle_new_user()             cascade;
drop function if exists public.set_updated_at()              cascade;

drop type if exists public.athlete_status    cascade;
drop type if exists public.membership_status cascade;
drop type if exists public.club_role         cascade;

