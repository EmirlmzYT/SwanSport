-- =============================================================================
-- SwanSport — SPORCU SU TÜKETİMİ ÖZ-YAZIM SÖZLEŞMESİ GÜVENCESİ
--
-- log_athlete_water RPC'sinde can_view_athlete_performance ile veli ve
-- kulüp görevlilerine açılmış olan yazma yetkisi kaldırılır.
-- Sözleşme: Sporcu yalnızca kendi su tüketimini kaydedebilir (is_athlete_self).
-- Antrenör ve veli yalnızca performansı görüntüleyebilir ve hedef belirleyebilir.
-- =============================================================================

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

  -- Yalnızca sporcunun kendisi su tüketimini kaydedebilir
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
