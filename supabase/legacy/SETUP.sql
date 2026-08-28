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


-- =============================================================================
-- SwanSport — Extended schema (announcements, events, invoices, attendance,
-- injuries, facilities, documents). Apply AFTER 0001 + 0002.
-- Reuses helper functions is_club_member() / is_club_staff() from 0002.
-- SQL Editor → New query → paste → Run. Safe to re-run.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.event_kind as enum ('training', 'match', 'meeting', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.invoice_status as enum ('paid', 'pending', 'overdue');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.attendance_status as enum ('present', 'absent', 'excused', 'late');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.fitness_status as enum ('fit', 'injured', 'pending');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- announcements
-- ---------------------------------------------------------------------------
create table if not exists public.announcements (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  author_id  uuid references public.profiles (id) on delete set null,
  title      text not null,
  body       text not null default '',
  pinned     boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- events (calendar)
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  team_id    uuid references public.teams (id) on delete set null,
  title      text not null,
  place      text,
  kind       public.event_kind not null default 'training',
  starts_at  timestamptz not null,
  ends_at    timestamptz,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- invoices (finance)
-- ---------------------------------------------------------------------------
create table if not exists public.invoices (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  athlete_id uuid references public.athletes (id) on delete set null,
  label      text not null,
  amount     numeric(12,2) not null default 0,
  status     public.invoice_status not null default 'pending',
  period     text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- attendance
-- ---------------------------------------------------------------------------
create table if not exists public.attendance (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  event_id   uuid references public.events (id) on delete set null,
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  status     public.attendance_status not null default 'present',
  taken_at   timestamptz not null default now(),
  unique (event_id, athlete_id)
);

-- ---------------------------------------------------------------------------
-- injuries (medical)
-- ---------------------------------------------------------------------------
create table if not exists public.injuries (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  status     public.fitness_status not null default 'fit',
  note       text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- facilities
-- ---------------------------------------------------------------------------
create table if not exists public.facilities (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  name       text not null,
  kind       text,
  occupancy  int not null default 0,   -- 0..100
  status     text not null default 'Müsait',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- documents
-- ---------------------------------------------------------------------------
create table if not exists public.documents (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs (id) on delete cascade,
  name       text not null,
  kind       text not null default 'file',   -- folder | pdf | xls | file
  size_label text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_ann_club   on public.announcements (club_id);
create index if not exists idx_ev_club    on public.events (club_id);
create index if not exists idx_inv_club   on public.invoices (club_id);
create index if not exists idx_att_club   on public.attendance (club_id);
create index if not exists idx_inj_club   on public.injuries (club_id);
create index if not exists idx_fac_club   on public.facilities (club_id);
create index if not exists idx_doc_club   on public.documents (club_id);

-- ---------------------------------------------------------------------------
-- RLS: members read · staff write   (helpers from 0002)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'announcements','events','invoices','attendance','injuries','facilities','documents'
  ] loop
    execute format('alter table public.%I enable row level security;', t);

    execute format($f$
      drop policy if exists "%1$s_read" on public.%1$s;
      create policy "%1$s_read" on public.%1$s for select
        using (public.is_club_member(club_id));
    $f$, t);

    execute format($f$
      drop policy if exists "%1$s_write" on public.%1$s;
      create policy "%1$s_write" on public.%1$s for all
        using (public.is_club_staff(club_id))
        with check (public.is_club_staff(club_id));
    $f$, t);
  end loop;
end $$;


-- =============================================================================
-- SwanSport — Roller & Doğrulama (0004). Apply AFTER 0001+0002 (+0003).
-- Kişi-düzeyi doğrulama · kulüp-beklemede + ≥2. kademe · platform onayı ·
-- davet kodu · kademe hiyerarşi tetikleyicisi. Safe to re-run.
-- =============================================================================

-- Not: 'member' rol değeri şimdilik kullanılmıyor; ihtiyaç olunca eklenecek.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin create type public.credential_kind as enum
  ('coach','athlete_licensed','athlete_individual');
exception when duplicate_object then null; end $$;

do $$ begin create type public.verification_status as enum
  ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

do $$ begin create type public.club_status as enum
  ('pending','active','suspended','rejected');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Platform yöneticisi bayrağı
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_platform_admin boolean not null default false;

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_platform_admin from public.profiles where id = auth.uid()), false);
$$;

-- ---------------------------------------------------------------------------
-- Kulüp: durum + inceleme alanları
-- ---------------------------------------------------------------------------
alter table public.clubs
  add column if not exists status public.club_status not null default 'pending',
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists reviewed_at timestamptz,
  add column if not exists review_note text;

-- ---------------------------------------------------------------------------
-- Üyelik: kademe + amir (1. kademe → 2. kademe bağı, kulüp düzeyinde)
-- ---------------------------------------------------------------------------
alter table public.club_memberships
  add column if not exists coach_level int,
  add column if not exists supervisor_id uuid references public.profiles(id);

-- ---------------------------------------------------------------------------
-- Kişi-düzeyi doğrulanmış kimlikler (kulüpten bağımsız)
-- ---------------------------------------------------------------------------
create table if not exists public.profile_credentials (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  kind         public.credential_kind not null,
  coach_level  int,                       -- kind='coach' için 1..5
  status       public.verification_status not null default 'pending',
  submitted_at timestamptz not null default now(),
  reviewed_by  uuid references public.profiles(id),
  reviewed_at  timestamptz,
  note         text
);
create index if not exists idx_cred_profile on public.profile_credentials(profile_id);

-- ---------------------------------------------------------------------------
-- Doğrulama evrakları (credential VEYA kulüp başvurusu sahibi)
-- ---------------------------------------------------------------------------
create table if not exists public.verification_documents (
  id           uuid primary key default gen_random_uuid(),
  owner_type   text not null,             -- 'credential' | 'club'
  owner_id     uuid not null,
  doc_type     text not null,             -- 'kademe_belgesi','kimlik','tescil','federasyon' ...
  storage_path text not null,             -- Supabase Storage yolu
  uploaded_by  uuid references public.profiles(id),
  uploaded_at  timestamptz not null default now()
);
create index if not exists idx_vdoc_owner on public.verification_documents(owner_type, owner_id);

-- ---------------------------------------------------------------------------
-- Davet kodları (veli ↔ sporcu bağı; tek kullanımlık + süreli)
-- ---------------------------------------------------------------------------
create table if not exists public.invite_codes (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  purpose    text not null default 'guardian_link',
  athlete_id uuid references public.athletes(id) on delete cascade,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours',
  used_at    timestamptz,
  used_by    uuid references public.profiles(id)
);
create index if not exists idx_invite_code on public.invite_codes(code);

-- ---------------------------------------------------------------------------
-- Kademe hiyerarşi tetikleyicisi:
-- 1. kademe antrenör, kulüpte ≥2. kademe biri yoksa eklenemez.
-- ---------------------------------------------------------------------------
create or replace function public.enforce_coach_hierarchy()
returns trigger language plpgsql as $$
begin
  if new.role = 'coach' and new.coach_level = 1 then
    if not exists (
      select 1 from public.club_memberships m
      where m.club_id = new.club_id
        and m.role = 'coach'
        and coalesce(m.coach_level, 0) >= 2
        and m.status = 'active'
    ) then
      raise exception '1. kademe antrenör eklenemez: kulüpte ≥2. kademe bir antrenör bulunmalı.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_coach_hierarchy on public.club_memberships;
create trigger trg_coach_hierarchy
  before insert on public.club_memberships
  for each row execute function public.enforce_coach_hierarchy();

-- ---------------------------------------------------------------------------
-- RPC: create_club — artık PENDING + kurucu ≥2. kademe doğrulanmış olmalı
-- (0002'deki sürümü değiştirir)
-- ---------------------------------------------------------------------------
create or replace function public.create_club(
  p_name       text,
  p_short_name text default null,
  p_city       text default null
)
returns public.clubs
language plpgsql security definer set search_path = public as $$
declare v_club public.clubs;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  -- Kurucu şartı: ≥2. kademe onaylı antrenör kimliği
  if not exists (
    select 1 from public.profile_credentials
    where profile_id = auth.uid()
      and kind = 'coach'
      and coalesce(coach_level, 0) >= 2
      and status = 'approved'
  ) then
    raise exception 'Kulüp kurmak için en az 2. kademe doğrulanmış antrenör olmalısın.';
  end if;

  insert into public.clubs (name, short_name, city, created_by, status)
  values (p_name, p_short_name, p_city, auth.uid(), 'pending')
  returning * into v_club;

  insert into public.club_memberships (club_id, profile_id, role, status)
  values (v_club.id, auth.uid(), 'club_admin', 'active');

  return v_club;
end;
$$;

-- ---------------------------------------------------------------------------
-- Platform onay/ret RPC'leri
-- ---------------------------------------------------------------------------
create or replace function public.approve_club(p_club uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.clubs
     set status='active', reviewed_by=auth.uid(), reviewed_at=now()
   where id=p_club;
end; $$;

create or replace function public.reject_club(p_club uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.clubs
     set status='rejected', reviewed_by=auth.uid(), reviewed_at=now(), review_note=p_note
   where id=p_club;
end; $$;

create or replace function public.review_credential(
  p_cred uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.profile_credentials
     set status = (case when p_approve then 'approved' else 'rejected' end)
                  ::public.verification_status,
         reviewed_by = auth.uid(), reviewed_at = now(), note = p_note
   where id = p_cred;
end; $$;

-- ---------------------------------------------------------------------------
-- Davet kodu RPC'leri
-- ---------------------------------------------------------------------------
create or replace function public.create_guardian_invite(p_athlete uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_code text; v_club uuid;
begin
  select club_id into v_club from public.athletes where id = p_athlete;
  if v_club is null or not public.is_club_staff(v_club) then
    raise exception 'Yetkisiz veya sporcu bulunamadı';
  end if;
  v_code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into public.invite_codes (code, athlete_id, created_by)
  values (v_code, p_athlete, auth.uid());
  return v_code;
end; $$;

create or replace function public.redeem_invite_code(p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare v_inv public.invite_codes; v_name text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  select * into v_inv from public.invite_codes
    where code = upper(p_code) and used_at is null and expires_at > now()
    limit 1;
  if v_inv.id is null then raise exception 'Kod geçersiz veya süresi dolmuş'; end if;

  select coalesce(full_name,'Veli') into v_name from public.profiles where id = auth.uid();
  insert into public.guardians (athlete_id, profile_id, display_name, relationship, can_contact)
  values (v_inv.athlete_id, auth.uid(), v_name, 'Veli', true);

  update public.invite_codes set used_at = now(), used_by = auth.uid() where id = v_inv.id;
end; $$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.profile_credentials    enable row level security;
alter table public.verification_documents enable row level security;
alter table public.invite_codes           enable row level security;

-- credentials: kişi kendi kaydını görür/ekler; platform admin hepsini görür/günceller
drop policy if exists "cred_own" on public.profile_credentials;
create policy "cred_own" on public.profile_credentials for select
  using (profile_id = auth.uid() or public.is_platform_admin());
drop policy if exists "cred_insert" on public.profile_credentials;
create policy "cred_insert" on public.profile_credentials for insert
  with check (profile_id = auth.uid());
drop policy if exists "cred_admin_update" on public.profile_credentials;
create policy "cred_admin_update" on public.profile_credentials for update
  using (public.is_platform_admin());

-- verification docs: yükleyen veya platform admin
drop policy if exists "vdoc_own" on public.verification_documents;
create policy "vdoc_own" on public.verification_documents for select
  using (uploaded_by = auth.uid() or public.is_platform_admin());
drop policy if exists "vdoc_insert" on public.verification_documents;
create policy "vdoc_insert" on public.verification_documents for insert
  with check (uploaded_by = auth.uid());

-- invite codes: kulüp personeli oluşturur/görür; herkes redeem RPC ile kullanır
drop policy if exists "invite_staff" on public.invite_codes;
create policy "invite_staff" on public.invite_codes for all
  using (created_by = auth.uid() or public.is_platform_admin())
  with check (created_by = auth.uid());

-- Platform admin: kulüpleri ve üyelikleri görebilsin (mevcut polic'​lere ek)
drop policy if exists "clubs_platform_read" on public.clubs;
create policy "clubs_platform_read" on public.clubs for select
  using (public.is_platform_admin());

-- ---- Mevcut kullanıcılar için profil backfill ----
insert into public.profiles (id, full_name) select id, coalesce(raw_user_meta_data->>'full_name','') from auth.users on conflict (id) do nothing;
