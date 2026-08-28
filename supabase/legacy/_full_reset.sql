-- =============================================================================
-- SwanSport — TAM KURULUM (tek dosya). Şemayı sıfırdan kurar.
-- ⚠️ Test aşaması: mevcut tabloları siler (gerçek veri yoksa güvenli).
-- SQL Editor → New query → tümünü yapıştır → Run.
-- =============================================================================

-- ---- Tam temizlik (re-runnable) ----
drop trigger if exists on_auth_user_created on auth.users;

drop table if exists public.verification_documents cascade;
drop table if exists public.invite_codes          cascade;
drop table if exists public.profile_credentials    cascade;
drop table if exists public.documents             cascade;
drop table if exists public.facilities            cascade;
drop table if exists public.injuries              cascade;
drop table if exists public.attendance            cascade;
drop table if exists public.invoices              cascade;
drop table if exists public.events                cascade;
drop table if exists public.announcements         cascade;
drop table if exists public.guardians             cascade;
drop table if exists public.team_memberships      cascade;
drop table if exists public.athletes              cascade;
drop table if exists public.club_memberships      cascade;
drop table if exists public.teams                 cascade;
drop table if exists public.seasons               cascade;
drop table if exists public.clubs                 cascade;
drop table if exists public.profiles              cascade;

drop function if exists public.redeem_invite_code(text) cascade;
drop function if exists public.create_guardian_invite(uuid) cascade;
drop function if exists public.review_credential(uuid, boolean, text) cascade;
drop function if exists public.reject_club(uuid, text) cascade;
drop function if exists public.approve_club(uuid) cascade;
drop function if exists public.enforce_coach_hierarchy() cascade;
drop function if exists public.is_platform_admin() cascade;
drop function if exists public.create_club(text, text, text) cascade;
drop function if exists public.is_guardian_of(uuid) cascade;
drop function if exists public.is_club_admin(uuid) cascade;
drop function if exists public.is_club_staff(uuid) cascade;
drop function if exists public.is_club_member(uuid) cascade;
drop function if exists public.handle_new_user() cascade;
drop function if exists public.set_updated_at() cascade;

drop type if exists public.club_status         cascade;
drop type if exists public.verification_status cascade;
drop type if exists public.credential_kind     cascade;
drop type if exists public.fitness_status      cascade;
drop type if exists public.attendance_status   cascade;
drop type if exists public.invoice_status      cascade;
drop type if exists public.event_kind          cascade;
drop type if exists public.athlete_status      cascade;
drop type if exists public.membership_status   cascade;
drop type if exists public.club_role           cascade;

