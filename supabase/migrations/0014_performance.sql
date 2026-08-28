-- =============================================================================
-- SwanSport — PERFORMANS MODÜLÜ
--   1) Test kayıtları (sürat, dayanıklılık, kuvvet, teknik)
--   2) Bireysel gelişim planı (IDP) hedefleri
--
-- Gizlilik: performans verisi başarılar gibi herkese açık DEĞİLDİR.
-- Yalnızca kulüp yetkilisi, sporcunun kendisi ve velisi görebilir.
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- Görüntüleme yetkisi
-- ---------------------------------------------------------------------------
create or replace function public.can_view_athlete_performance(p_athlete uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.athletes a
    where a.id = p_athlete
      and (
        public.can_manage_athlete(a.id)          -- kulüp yetkilisi / ferdi sporcu
        or a.profile_id = auth.uid()             -- sporcunun kendisi
        or public.is_guardian_of(a.id)           -- velisi
      )
  );
$$;


-- ---------------------------------------------------------------------------
-- 1) TEST KAYITLARI
-- ---------------------------------------------------------------------------
create table if not exists public.performance_tests (
  id          uuid primary key default gen_random_uuid(),
  athlete_id  uuid not null references public.athletes(id) on delete cascade,
  category    text not null default 'surat',  -- surat|dayaniklilik|kuvvet|teknik
  test_name   text not null,                  -- "30 m sprint"
  value       numeric(10,2) not null,
  unit        text not null default '',       -- sn, m, kg, tekrar, puan
  -- Bazı testlerde küçük değer iyidir (sprint süresi gibi).
  lower_is_better boolean not null default false,
  test_date   date not null default current_date,
  note        text,
  assessor_id uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_perf_athlete
  on public.performance_tests (athlete_id, test_name, test_date);

alter table public.performance_tests enable row level security;

drop policy if exists "perf_read" on public.performance_tests;
create policy "perf_read" on public.performance_tests for select
  to authenticated
  using (public.can_view_athlete_performance(athlete_id));

drop policy if exists "perf_write" on public.performance_tests;
create policy "perf_write" on public.performance_tests for all
  to authenticated
  using (public.can_manage_athlete(athlete_id))
  with check (public.can_manage_athlete(athlete_id));


-- ---------------------------------------------------------------------------
-- 2) BİREYSEL GELİŞİM PLANI (IDP)
-- ---------------------------------------------------------------------------
create table if not exists public.development_goals (
  id           uuid primary key default gen_random_uuid(),
  athlete_id   uuid not null references public.athletes(id) on delete cascade,
  title        text not null,
  category     text not null default 'surat',
  progress     int  not null default 0,   -- 0..100
  target_date  date,
  status       text not null default 'active', -- active | done | at_risk
  note         text,
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index if not exists idx_goal_athlete
  on public.development_goals (athlete_id, status);

alter table public.development_goals enable row level security;

drop policy if exists "goal_read" on public.development_goals;
create policy "goal_read" on public.development_goals for select
  to authenticated
  using (public.can_view_athlete_performance(athlete_id));

drop policy if exists "goal_write" on public.development_goals;
create policy "goal_write" on public.development_goals for all
  to authenticated
  using (public.can_manage_athlete(athlete_id))
  with check (public.can_manage_athlete(athlete_id));


-- ---------------------------------------------------------------------------
-- 3) Kulüp özeti — kadroda kimin kaç testi ve hedefi var
-- ---------------------------------------------------------------------------
create or replace function public.performance_overview(p_club uuid)
returns table (
  athlete_id  uuid,
  full_name   text,
  test_count  int,
  goal_count  int,
  avg_progress int,
  last_test   date
)
language sql stable security definer set search_path = public as $$
  select
    a.id,
    (a.first_name || ' ' || coalesce(a.last_name, '')) as full_name,
    (select count(*) from public.performance_tests t
      where t.athlete_id = a.id)::int,
    (select count(*) from public.development_goals g
      where g.athlete_id = a.id and g.status <> 'done')::int,
    coalesce((select round(avg(g.progress)) from public.development_goals g
      where g.athlete_id = a.id and g.status <> 'done'), 0)::int,
    (select max(t.test_date) from public.performance_tests t
      where t.athlete_id = a.id)
  from public.athletes a
  where a.club_id = p_club
    and public.is_club_staff(p_club)
  order by full_name;
$$;
