-- =============================================================================
-- SwanSport — Demo seed (mirrors the fixture data)
-- =============================================================================
-- Run this LAST, and only AFTER you have signed up in the app at least once
-- (so your auth user + profile exist).
--
-- 1. Replace 'REPLACE_WITH_YOUR_EMAIL' below with the email you signed up with.
-- 2. SQL Editor → New query → paste → Run.
--
-- It creates the demo club "Kadıköy SK", a U-16 team, a season, three athletes,
-- and makes YOU the club admin so the app can load real data after login.
-- Safe to re-run: it skips creation if the demo club already exists.
-- =============================================================================

do $$
declare
  v_owner_email text := 'REPLACE_WITH_YOUR_EMAIL';
  v_uid    uuid;
  v_club   uuid;
  v_season uuid;
  v_team   uuid;
  v_ath    uuid;
begin
  -- Locate the signed-up user.
  select id into v_uid from auth.users where email = v_owner_email limit 1;
  if v_uid is null then
    raise exception 'No auth user found for %. Sign up in the app first.', v_owner_email;
  end if;

  -- Skip if the demo club already exists (idempotent).
  select id into v_club from public.clubs where name = 'Kadıköy SK' limit 1;
  if v_club is not null then
    raise notice 'Demo club already exists (%). Nothing to seed.', v_club;
    return;
  end if;

  -- Club
  insert into public.clubs (name, short_name, city, created_by)
  values ('Kadıköy SK', 'KSK', 'İstanbul', v_uid)
  returning id into v_club;

  -- Make the current user the club admin
  insert into public.club_memberships (club_id, profile_id, role, status)
  values (v_club, v_uid, 'club_admin', 'active');

  -- Season
  insert into public.seasons (club_id, label, is_active, starts_on, ends_on)
  values (v_club, '2025-2026 Sezonu', true, '2025-09-01', '2026-06-30')
  returning id into v_season;

  -- Team
  insert into public.teams (club_id, name, age_group, gender)
  values (v_club, 'U-16 Erkek', 'U-16', 'male')
  returning id into v_team;

  -- Athlete 1 — Can Yılmaz #10
  insert into public.athletes
    (club_id, first_name, last_name, birth_date, position, license_number, status)
  values
    (v_club, 'Can', 'Yılmaz', '2010-05-14', 'Point Guard', 'TR-2026-8842', 'active')
  returning id into v_ath;
  insert into public.team_memberships (athlete_id, team_id, season_id, jersey_number)
  values (v_ath, v_team, v_season, '10');
  insert into public.guardians (athlete_id, display_name, relationship, phone, can_contact)
  values (v_ath, 'Yılmaz Ailesi', 'Veli', '+90 500 000 0000', true);

  -- Athlete 2 — Efe Kaya #07
  insert into public.athletes
    (club_id, first_name, last_name, birth_date, position, license_number, status)
  values
    (v_club, 'Efe', 'Kaya', '2010-02-03', 'Shooting Guard', null, 'pending_license')
  returning id into v_ath;
  insert into public.team_memberships (athlete_id, team_id, season_id, jersey_number)
  values (v_ath, v_team, v_season, '07');

  -- Athlete 3 — Arda Şen
  insert into public.athletes
    (club_id, first_name, last_name, birth_date, position, license_number, status)
  values
    (v_club, 'Arda', 'Şen', '2010-11-20', 'Forward', 'TR-2026-9013', 'active')
  returning id into v_ath;
  insert into public.team_memberships (athlete_id, team_id, season_id, jersey_number)
  values (v_ath, v_team, v_season, '12');

  raise notice 'Seeded demo club % with 3 athletes. You are the admin.', v_club;
end $$;
