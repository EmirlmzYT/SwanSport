-- =============================================================================
-- SwanSport — SPORCU BESLENME VE HİDRASYON TAKİBİ
--
-- Sporcunun günlük kalori, makro besin ve su tüketim takibi.
-- Sporcu yalnızca kendi kaydını ekler/düzenler; yetkili antrenör ve veli
-- can_view_athlete_performance üzerinden okuyabilir.
-- =============================================================================

create table if not exists public.athlete_nutrition_logs (
  id          uuid primary key default gen_random_uuid(),
  athlete_id  uuid not null references public.athletes (id) on delete cascade,
  log_date    date not null default current_date,
  meal_type   text not null,
  title       text not null,
  calories    int not null default 0,
  protein_g   numeric(6,1) not null default 0,
  carb_g      numeric(6,1) not null default 0,
  fat_g       numeric(6,1) not null default 0,
  water_ml    int not null default 0,
  created_at  timestamptz not null default now(),

  constraint chk_nutrition_meal_type check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack', 'water')),
  constraint chk_nutrition_calories check (calories >= 0),
  constraint chk_nutrition_water check (water_ml >= 0)
);

create index if not exists idx_nutrition_athlete_date
  on public.athlete_nutrition_logs (athlete_id, log_date);

alter table public.athlete_nutrition_logs enable row level security;

drop policy if exists "athlete_nutrition_read" on public.athlete_nutrition_logs;
create policy "athlete_nutrition_read" on public.athlete_nutrition_logs
  for select using (
    public.is_athlete_self(athlete_id)
    or public.can_view_athlete_performance(athlete_id)
  );

drop policy if exists "athlete_nutrition_insert" on public.athlete_nutrition_logs;
create policy "athlete_nutrition_insert" on public.athlete_nutrition_logs
  for insert with check (public.is_athlete_self(athlete_id));

drop policy if exists "athlete_nutrition_update" on public.athlete_nutrition_logs;
create policy "athlete_nutrition_update" on public.athlete_nutrition_logs
  for update using (public.is_athlete_self(athlete_id));

drop policy if exists "athlete_nutrition_delete" on public.athlete_nutrition_logs;
create policy "athlete_nutrition_delete" on public.athlete_nutrition_logs
  for delete using (public.is_athlete_self(athlete_id));

grant select, insert, update, delete on public.athlete_nutrition_logs to authenticated;
