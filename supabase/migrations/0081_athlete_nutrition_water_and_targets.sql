-- =============================================================================
-- SwanSport — SPORCU SU TAKİBİ ATOMİK İŞLEM VE YAPILANDIRILABİLİR HEDEFLER
--
-- 1) Su takibinde (meal_type = 'water') yarış durumunu önlemek için tekil indeks
--    ve sunucu tarafında atomik artırma/azaltma RPC'si (log_athlete_water).
-- 2) Mevcut mükerrer su kayıtlarını toplam suyu koruyarak tek satırda birleştirme.
-- 3) Bilimsel dayanağı olmayan sabit 2500 kcal / 3000 ml dayatması yerine
--    kişiselleştirilebilir ve antrenör/uzman onaylı beslenme hedefleri tablosu.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) MEVCUT MÜKERRER SU KAYITLARININ GÜVENLE BİRLEŞTİRİLMESİ
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  v_kept_id uuid;
begin
  for r in
    select athlete_id, log_date, count(*) as cnt, sum(water_ml) as total_ml
      from public.athlete_nutrition_logs
     where meal_type = 'water'
     group by athlete_id, log_date
    having count(*) > 1
  loop
    select id into v_kept_id
      from public.athlete_nutrition_logs
     where athlete_id = r.athlete_id and log_date = r.log_date and meal_type = 'water'
     order by created_at asc
     limit 1;

    update public.athlete_nutrition_logs
       set water_ml = least(greatest(r.total_ml, 0), 15000)
     where id = v_kept_id;

    delete from public.athlete_nutrition_logs
     where athlete_id = r.athlete_id and log_date = r.log_date and meal_type = 'water'
       and id <> v_kept_id;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2) TEKİL SU KAYDI KISITI (PARTIAL UNIQUE INDEX)
-- ---------------------------------------------------------------------------
create unique index if not exists idx_athlete_nutrition_water_uniq
  on public.athlete_nutrition_logs (athlete_id, log_date)
  where (meal_type = 'water');

-- ---------------------------------------------------------------------------
-- 3) ATOMİK SU GÜNCELLEME RPC'Sİ
-- ---------------------------------------------------------------------------
create or replace function public.log_athlete_water(
  p_athlete_id uuid,
  p_date       date,
  p_delta_ml   int
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_val int;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if not public.is_athlete_self(p_athlete_id) then
    raise exception 'Yalnızca sporcunun kendisi su tüketimi kaydı girebilir';
  end if;

  -- Makul delta sınırları: tek seferde en fazla +-3000 ml
  if p_delta_ml < -3000 or p_delta_ml > 3000 then
    raise exception 'Tek seferlik su miktarı değişimi -3000 ile +3000 ml arasında olmalıdır';
  end if;

  insert into public.athlete_nutrition_logs (
    athlete_id, log_date, meal_type, title, calories, protein_g, carb_g, fat_g, water_ml
  ) values (
    p_athlete_id, p_date, 'water', 'Su Tüketimi', 0, 0, 0, 0, greatest(p_delta_ml, 0)
  )
  on conflict (athlete_id, log_date) where (meal_type = 'water')
  do update set
    water_ml = least(greatest(public.athlete_nutrition_logs.water_ml + p_delta_ml, 0), 15000)
  returning water_ml into v_new_val;

  return v_new_val;
end;
$$;

revoke execute on function public.log_athlete_water(uuid, date, int) from public, anon;
grant execute on function public.log_athlete_water(uuid, date, int) to authenticated;


-- ---------------------------------------------------------------------------
-- 4) YAPILANDIRILABİLİR BESLENME VE HİDRASYON HEDEFLERİ
-- ---------------------------------------------------------------------------
create table if not exists public.athlete_nutrition_targets (
  athlete_id       uuid primary key references public.athletes (id) on delete cascade,
  target_calories  int check (target_calories is null or (target_calories between 500 and 10000)),
  target_water_ml  int check (target_water_ml is null or (target_water_ml between 500 and 10000)),
  set_by           uuid references public.profiles (id) on delete set null,
  updated_at       timestamptz not null default now()
);

alter table public.athlete_nutrition_targets enable row level security;

drop policy if exists "athlete_nutrition_targets_read" on public.athlete_nutrition_targets;
create policy "athlete_nutrition_targets_read" on public.athlete_nutrition_targets
  for select using (
    public.is_athlete_self(athlete_id)
    or public.can_view_athlete_performance(athlete_id)
  );

drop policy if exists "athlete_nutrition_targets_write" on public.athlete_nutrition_targets;
create policy "athlete_nutrition_targets_write" on public.athlete_nutrition_targets
  for all using (
    public.is_athlete_self(athlete_id)
    or public.can_view_athlete_performance(athlete_id)
  )
  with check (
    public.is_athlete_self(athlete_id)
    or public.can_view_athlete_performance(athlete_id)
  );

grant select, insert, update on public.athlete_nutrition_targets to authenticated;

-- Hedef belirleme RPC'si
create or replace function public.set_athlete_nutrition_targets(
  p_athlete_id      uuid,
  p_target_calories int default null,
  p_target_water_ml int default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if not (public.is_athlete_self(p_athlete_id) or public.can_view_athlete_performance(p_athlete_id)) then
    raise exception 'Bu sporcu için beslenme hedefi belirleme yetkiniz yok';
  end if;

  if p_target_calories is not null and (p_target_calories < 500 or p_target_calories > 10000) then
    raise exception 'Hedef kalori 500 ile 10000 kcal arasında olmalıdır';
  end if;

  if p_target_water_ml is not null and (p_target_water_ml < 500 or p_target_water_ml > 10000) then
    raise exception 'Hedef su tüketimi 500 ile 10000 ml arasında olmalıdır';
  end if;

  insert into public.athlete_nutrition_targets (
    athlete_id, target_calories, target_water_ml, set_by, updated_at
  )
  values (
    p_athlete_id, p_target_calories, p_target_water_ml, auth.uid(), now()
  )
  on conflict (athlete_id)
  do update set
    target_calories = excluded.target_calories,
    target_water_ml = excluded.target_water_ml,
    set_by = auth.uid(),
    updated_at = now();
end;
$$;

revoke execute on function public.set_athlete_nutrition_targets(uuid, int, int) from public, anon;
grant execute on function public.set_athlete_nutrition_targets(uuid, int, int) to authenticated;
