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
