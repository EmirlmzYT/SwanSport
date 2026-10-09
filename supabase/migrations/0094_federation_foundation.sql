-- Phase A: institutions are distinct from announcement communities. No guest grants.
set local lock_timeout = '15s';

create table if not exists public.federations (
 id uuid primary key default gen_random_uuid(), sport_code text not null unique references public.sports(code),
 name text not null check(length(trim(name)) between 1 and 180));
create table if not exists public.federation_offices (
 id uuid primary key default gen_random_uuid(), federation_id uuid not null references public.federations(id),
 city_code text references public.cities(code), name text not null,
 unique nulls not distinct(federation_id,city_code));
create table if not exists public.federation_appointments (
 id uuid primary key default gen_random_uuid(), profile_id uuid references public.profiles(id) on delete set null,
 office_id uuid not null references public.federation_offices(id),
 duty text not null check(duty in ('result_publisher','program_publisher','license_registrar','club_registrar')),
 starts_on date not null, ends_on date not null, revoked_at timestamptz,
 granted_by uuid references public.profiles(id) on delete set null,
 check(ends_on >= starts_on));
create index if not exists federation_appointment_actor on public.federation_appointments(profile_id,office_id,duty);
create table if not exists public.federation_audit (
 id bigint generated always as identity primary key, actor_id uuid references public.profiles(id) on delete set null,
 appointment_id uuid references public.federation_appointments(id), action text not null,
 entity_id uuid not null, detail jsonb not null default '{}', recorded_at timestamptz not null default clock_timestamp());
create table if not exists public.sport_seasons (
 id uuid primary key default gen_random_uuid(), office_id uuid not null references public.federation_offices(id),
 label text not null, starts_on date not null, ends_on date not null,
 check(ends_on>=starts_on), unique(office_id,label));

alter table public.clubs
 add column if not exists legal_name text,
 add column if not exists registration_no text,
 add column if not exists registration_sport_code text references public.sports(code),
 add column if not exists registration_city_code text references public.cities(code),
 add column if not exists registration_status text not null default 'unregistered';
-- Approval is sport scoped; clubs' fields are the legal identity, not permission for every sport.
create table if not exists public.club_sport_registrations (
 club_id uuid not null, -- historical club key; deletion must not cascade or block official history
 sport_code text not null references public.sports(code), registration_no text not null,
 approved_on date not null, primary key(club_id,sport_code), unique(sport_code,registration_no));
alter table public.teams add column if not exists sport_code text references public.sports(code);
update public.teams t set sport_code=c.sport_code from public.clubs c where t.club_id=c.id and t.sport_code is null;
alter table public.profile_credentials add column if not exists expires_on date;

-- Historical results cannot cascade through the organizer's personal account/club.
alter table public.organizations alter column owner_id drop not null;
alter table public.organizations drop constraint if exists organizations_owner_id_fkey;
alter table public.organizations add constraint organizations_owner_id_fkey foreign key(owner_id) references public.profiles(id) on delete set null;
alter table public.organizations drop constraint if exists organizations_club_id_fkey;
alter table public.organizations add constraint organizations_club_id_fkey foreign key(club_id) references public.clubs(id) on delete set null;
alter table public.organizations
 add column if not exists federation_office_id uuid references public.federation_offices(id),
 add column if not exists sport_season_id uuid references public.sport_seasons(id),
 add column if not exists official boolean not null default false,
 add column if not exists published_at timestamptz;
do $$ begin alter table public.organizations add constraint org_official_owner check(
 (official and federation_office_id is not null and sport_season_id is not null and sport_code is not null and club_id is null and owner_id is null)
 or (not official and federation_office_id is null and sport_season_id is null));
exception when duplicate_object then null; end $$;
alter table public.org_matches add column if not exists result_protocol jsonb,
 add column if not exists result_version int not null default 0;
create table if not exists public.org_result_revisions (
 id uuid primary key default gen_random_uuid(), match_id uuid not null references public.org_matches(id) on delete restrict,
 version int not null, protocol jsonb not null, reason text not null,
 home_roster_revision_id uuid, away_roster_revision_id uuid,
 actor_id uuid references public.profiles(id) on delete set null, recorded_at timestamptz not null default clock_timestamp(),
 unique(match_id,version));
-- Reference snapshots are added after roster table exists below.
-- athlete_id is a durable historical key, deliberately NOT a cascade FK. No personal snapshot.
create table if not exists public.org_roster_revisions (
 id uuid primary key default gen_random_uuid(), participant_id uuid not null references public.org_participants(id) on delete restrict,
 version int not null, athlete_ids uuid[] not null, reason text not null,
 actor_id uuid references public.profiles(id) on delete set null, published_at timestamptz not null default clock_timestamp(),
 unique(participant_id,version));
do $$ begin
 alter table public.org_result_revisions add constraint result_home_roster_fk foreign key(home_roster_revision_id) references public.org_roster_revisions(id) on delete restrict;
exception when duplicate_object then null; end $$;
do $$ begin
 alter table public.org_result_revisions add constraint result_away_roster_fk foreign key(away_roster_revision_id) references public.org_roster_revisions(id) on delete restrict;
exception when duplicate_object then null; end $$;
create table if not exists public.athlete_sport_registrations (
 athlete_id uuid not null, sport_code text not null references public.sports(code),
 club_id uuid references public.clubs(id) on delete set null,
 license_number text not null, expires_on date not null,
 primary key(athlete_id,sport_code), unique(sport_code,license_number));
create table if not exists public.athlete_transfers (
 id uuid primary key default gen_random_uuid(), athlete_id uuid not null,
 sport_code text not null references public.sports(code), from_club_id uuid references public.clubs(id) on delete set null,
 to_club_id uuid references public.clubs(id) on delete set null, transferred_on date not null,
 reason text not null, recorded_at timestamptz not null default clock_timestamp());
create table if not exists public.official_disputes (
 id uuid primary key default gen_random_uuid(), match_id uuid not null references public.org_matches(id) on delete restrict,
 submitted_by uuid references public.profiles(id) on delete set null,
 body text not null check(length(trim(body)) between 1 and 2000),
 responds_to uuid references public.official_disputes(id), created_at timestamptz not null default clock_timestamp());
create table if not exists public.athlete_publicity (
 athlete_id uuid not null references public.athletes(id) on delete cascade,
 guardian_id uuid not null references public.guardians(id) on delete cascade,
 allowed boolean not null default false, updated_at timestamptz not null default clock_timestamp(),
 primary key(athlete_id,guardian_id));
alter table public.athlete_achievements add column if not exists official_match_id uuid references public.org_matches(id) on delete restrict,
 add column if not exists supersedes_id uuid references public.athlete_achievements(id) on delete restrict;
-- Keep earned club achievements but preserve federation results when athlete's club is deleted.
alter table public.athlete_achievements drop constraint if exists athlete_achievements_athlete_id_fkey;

-- Central check: no platform-admin shortcut. Lock the appointment through the write transaction.
drop function if exists public._federation_require(text,text,text);
create function public._federation_require(p_sport text,p_city text,p_duty text)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid;
begin
 select a.id into v_id from public.federation_appointments a
 join public.federation_offices o on o.id=a.office_id join public.federations f on f.id=o.federation_id
 where a.profile_id=auth.uid() and a.duty=p_duty and a.revoked_at is null
 and a.starts_on <= (clock_timestamp() at time zone 'Europe/Istanbul')::date
 and a.ends_on >= (clock_timestamp() at time zone 'Europe/Istanbul')::date
 and f.sport_code=p_sport and (o.city_code is null or o.city_code=p_city)
 order by a.id limit 1 for share of a,o,f;
 if v_id is null then raise exception 'Aktif branş/il/görev yetkisi gerekli' using errcode='42501'; end if;
 return v_id;
end $$;
revoke all on function public._federation_require(text,text,text) from public,anon,authenticated;

drop function if exists public.coach_level_for_sport(uuid,text);
create function public.coach_level_for_sport(p_profile uuid,p_sport text)
returns int language sql stable security definer set search_path=public as $$
 select coalesce(max(coach_level),0) from public.profile_credentials
 where profile_id=p_profile and sport_code=p_sport and kind='coach' and status='approved'
 and (expires_on is null or expires_on >= (now() at time zone 'Europe/Istanbul')::date)
$$;
revoke all on function public.coach_level_for_sport(uuid,text) from public,anon,authenticated;

-- All foundation tables deny direct writes and guest reads, including Supabase default privileges.
do $$ declare t text; begin
 foreach t in array array['federations','federation_offices','federation_appointments','federation_audit','sport_seasons',
 'club_sport_registrations','org_result_revisions','org_roster_revisions','athlete_sport_registrations','athlete_transfers',
 'official_disputes','athlete_publicity'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 end loop;
end $$;
revoke all on sequence public.federation_audit_id_seq from public,anon,authenticated;
grant select on public.federation_appointments to authenticated;
drop policy if exists appointment_own_read on public.federation_appointments;
create policy appointment_own_read on public.federation_appointments for select to authenticated using(profile_id=auth.uid());
