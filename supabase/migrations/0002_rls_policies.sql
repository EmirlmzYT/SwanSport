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
