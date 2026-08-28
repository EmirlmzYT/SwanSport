-- ============================================================
-- SwanSport — Combined RESET + schema + RLS (re-runnable)
-- Run this once in Supabase SQL Editor. Safe to re-run.
-- ============================================================

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

-- =============================================================================
-- SwanSport — Foundation schema (vertical slice 1: Auth + Athlete management)
-- =============================================================================
-- Tables: profiles, clubs, seasons, teams, club_memberships, athletes,
--         team_memberships, guardians.
--
-- Apply this file FIRST, then 0002_rls_policies.sql.
-- In the Supabase dashboard: SQL Editor → New query → paste → Run.
-- =============================================================================

create extension if not exists "pgcrypto";

-- ----------------------------------------------------------------------------
-- Shared helpers
-- ----------------------------------------------------------------------------

-- Keeps updated_at fresh on row updates.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- Enums
-- ----------------------------------------------------------------------------

-- Roles a person can hold inside a club. Drives the role-selection sheet.
create type public.club_role as enum (
  'club_admin',
  'coach',
  'athlete',
  'parent',
  'official',
  'federation_rep'
);

create type public.membership_status as enum (
  'active',
  'invited',
  'suspended'
);

create type public.athlete_status as enum (
  'active',
  'injured',
  'inactive',
  'pending_license'
);

-- ----------------------------------------------------------------------------
-- profiles — one row per authenticated user (mirrors auth.users)
-- ----------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text        not null default '',
  national_id text,               -- TCKN
  phone       text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- clubs
-- ----------------------------------------------------------------------------
create table public.clubs (
  id         uuid primary key default gen_random_uuid(),
  name       text        not null,
  short_name text,
  city       text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- seasons
-- ----------------------------------------------------------------------------
create table public.seasons (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid        not null references public.clubs (id) on delete cascade,
  label      text        not null,        -- e.g. "2025-2026 Sezonu"
  starts_on  date,
  ends_on    date,
  is_active  boolean     not null default false,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- teams
-- ----------------------------------------------------------------------------
create table public.teams (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid        not null references public.clubs (id) on delete cascade,
  name       text        not null,        -- e.g. "U-16 Erkek"
  age_group  text,                        -- e.g. "U-16"
  gender     text,                        -- e.g. "male" | "female" | "mixed"
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- club_memberships — links a profile to a club with a role
-- ----------------------------------------------------------------------------
create table public.club_memberships (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid        not null references public.clubs (id) on delete cascade,
  profile_id uuid        not null references public.profiles (id) on delete cascade,
  role       public.club_role         not null,
  team_id    uuid references public.teams (id) on delete set null, -- optional scope
  status     public.membership_status not null default 'active',
  created_at timestamptz not null default now(),
  unique (club_id, profile_id, role, team_id)
);

-- ----------------------------------------------------------------------------
-- athletes — an athlete may or may not have a login (profile_id nullable)
-- ----------------------------------------------------------------------------
create table public.athletes (
  id             uuid primary key default gen_random_uuid(),
  club_id        uuid    not null references public.clubs (id) on delete cascade,
  profile_id     uuid references public.profiles (id) on delete set null,
  first_name     text    not null,
  last_name      text    not null,
  national_id    text,
  birth_date     date,
  position       text,                     -- e.g. "Point Guard"
  license_number text,
  status         public.athlete_status not null default 'active',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- team_memberships — athlete on a team for a season, with jersey number
-- ----------------------------------------------------------------------------
create table public.team_memberships (
  id            uuid primary key default gen_random_uuid(),
  athlete_id    uuid not null references public.athletes (id) on delete cascade,
  team_id       uuid not null references public.teams (id) on delete cascade,
  season_id     uuid references public.seasons (id) on delete set null,
  jersey_number text,
  created_at    timestamptz not null default now(),
  unique (athlete_id, team_id, season_id)
);

-- ----------------------------------------------------------------------------
-- guardians — parents/guardians linked to an athlete
-- ----------------------------------------------------------------------------
create table public.guardians (
  id           uuid primary key default gen_random_uuid(),
  athlete_id   uuid not null references public.athletes (id) on delete cascade,
  profile_id   uuid references public.profiles (id) on delete set null,
  display_name text not null,
  relationship text,                       -- e.g. "Anne", "Baba"
  phone        text,
  can_contact  boolean not null default true,
  created_at   timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Indexes for common lookups
-- ----------------------------------------------------------------------------
create index idx_seasons_club            on public.seasons (club_id);
create index idx_teams_club              on public.teams (club_id);
create index idx_memberships_profile     on public.club_memberships (profile_id);
create index idx_memberships_club        on public.club_memberships (club_id);
create index idx_athletes_club           on public.athletes (club_id);
create index idx_team_memberships_team   on public.team_memberships (team_id);
create index idx_team_memberships_athlete on public.team_memberships (athlete_id);
create index idx_guardians_athlete       on public.guardians (athlete_id);

-- ----------------------------------------------------------------------------
-- updated_at triggers
-- ----------------------------------------------------------------------------
create trigger trg_profiles_updated  before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_clubs_updated     before update on public.clubs
  for each row execute function public.set_updated_at();
create trigger trg_teams_updated     before update on public.teams
  for each row execute function public.set_updated_at();
create trigger trg_athletes_updated  before update on public.athletes
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- Auto-provision a profile row when a new auth user signs up
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, national_id, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'national_id',
    new.raw_user_meta_data ->> 'phone'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- =============================================================================
-- SwanSport — Row Level Security policies (vertical slice 1)
-- =============================================================================
-- Apply AFTER 0001_foundation.sql.
--
-- Access model:
--   * Every user reads/writes their own profile.
--   * Club STAFF (club_admin, coach, official) manage club data.
--   * Athletes and their guardians read the athlete's own record.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- Membership helper functions (SECURITY DEFINER to avoid RLS recursion)
-- ----------------------------------------------------------------------------

create or replace function public.is_club_member(target_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.club_memberships
    where profile_id = auth.uid()
      and club_id = target_club
      and status = 'active'
  );
$$;

create or replace function public.is_club_staff(target_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.club_memberships
    where profile_id = auth.uid()
      and club_id = target_club
      and status = 'active'
      and role in ('club_admin', 'coach', 'official')
  );
$$;

create or replace function public.is_club_admin(target_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.club_memberships
    where profile_id = auth.uid()
      and club_id = target_club
      and status = 'active'
      and role = 'club_admin'
  );
$$;

create or replace function public.is_guardian_of(p_athlete uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.guardians
    where athlete_id = p_athlete
      and profile_id = auth.uid()
  );
$$;

-- ----------------------------------------------------------------------------
-- Atomic club bootstrap: create a club and make the caller its admin.
-- Solves the chicken-and-egg where inserting the first membership would
-- otherwise require already being an admin.
-- ----------------------------------------------------------------------------
create or replace function public.create_club(
  p_name       text,
  p_short_name text default null,
  p_city       text default null
)
returns public.clubs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club public.clubs;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.clubs (name, short_name, city, created_by)
  values (p_name, p_short_name, p_city, auth.uid())
  returning * into v_club;

  insert into public.club_memberships (club_id, profile_id, role, status)
  values (v_club.id, auth.uid(), 'club_admin', 'active');

  return v_club;
end;
$$;

-- ============================================================================
-- profiles
-- ============================================================================
alter table public.profiles enable row level security;

create policy "profiles: read own"
  on public.profiles for select
  using (id = auth.uid());

create policy "profiles: read club co-members"
  on public.profiles for select
  using (
    exists (
      select 1
      from public.club_memberships me
      join public.club_memberships them
        on them.club_id = me.club_id
      where me.profile_id = auth.uid()
        and me.status = 'active'
        and them.profile_id = public.profiles.id
    )
  );

create policy "profiles: update own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- ============================================================================
-- clubs
-- ============================================================================
alter table public.clubs enable row level security;

create policy "clubs: members read"
  on public.clubs for select
  using (public.is_club_member(id));

create policy "clubs: admin update"
  on public.clubs for update
  using (public.is_club_admin(id))
  with check (public.is_club_admin(id));

-- Inserts go through public.create_club(); direct inserts are limited to the
-- creator setting themselves as created_by.
create policy "clubs: creator insert"
  on public.clubs for insert
  with check (created_by = auth.uid());

-- ============================================================================
-- seasons
-- ============================================================================
alter table public.seasons enable row level security;

create policy "seasons: members read"
  on public.seasons for select
  using (public.is_club_member(club_id));

create policy "seasons: staff write"
  on public.seasons for all
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

-- ============================================================================
-- teams
-- ============================================================================
alter table public.teams enable row level security;

create policy "teams: members read"
  on public.teams for select
  using (public.is_club_member(club_id));

create policy "teams: staff write"
  on public.teams for all
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

-- ============================================================================
-- club_memberships
-- ============================================================================
alter table public.club_memberships enable row level security;

create policy "memberships: read own"
  on public.club_memberships for select
  using (profile_id = auth.uid());

create policy "memberships: staff read club"
  on public.club_memberships for select
  using (public.is_club_staff(club_id));

create policy "memberships: admin write"
  on public.club_memberships for all
  using (public.is_club_admin(club_id))
  with check (public.is_club_admin(club_id));

-- ============================================================================
-- athletes
-- ============================================================================
alter table public.athletes enable row level security;

create policy "athletes: staff read"
  on public.athletes for select
  using (public.is_club_staff(club_id));

create policy "athletes: self read"
  on public.athletes for select
  using (profile_id = auth.uid());

create policy "athletes: guardian read"
  on public.athletes for select
  using (public.is_guardian_of(id));

create policy "athletes: staff write"
  on public.athletes for all
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

-- ============================================================================
-- team_memberships (scoped through the athlete's club)
-- ============================================================================
alter table public.team_memberships enable row level security;

create policy "team_memberships: read"
  on public.team_memberships for select
  using (
    exists (
      select 1 from public.athletes a
      where a.id = athlete_id
        and (
          public.is_club_staff(a.club_id)
          or a.profile_id = auth.uid()
          or public.is_guardian_of(a.id)
        )
    )
  );

create policy "team_memberships: staff write"
  on public.team_memberships for all
  using (
    exists (
      select 1 from public.athletes a
      where a.id = athlete_id and public.is_club_staff(a.club_id)
    )
  )
  with check (
    exists (
      select 1 from public.athletes a
      where a.id = athlete_id and public.is_club_staff(a.club_id)
    )
  );

-- ============================================================================
-- guardians
-- ============================================================================
alter table public.guardians enable row level security;

create policy "guardians: read"
  on public.guardians for select
  using (
    profile_id = auth.uid()
    or exists (
      select 1 from public.athletes a
      where a.id = athlete_id
        and (public.is_club_staff(a.club_id) or a.profile_id = auth.uid())
    )
  );

create policy "guardians: staff write"
  on public.guardians for all
  using (
    exists (
      select 1 from public.athletes a
      where a.id = athlete_id and public.is_club_staff(a.club_id)
    )
  )
  with check (
    exists (
      select 1 from public.athletes a
      where a.id = athlete_id and public.is_club_staff(a.club_id)
    )
  );
