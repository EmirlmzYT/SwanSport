-- 0124: Profilde sütun düzeyinde iletişim ve çocuk verisi gizliliği.
-- RLS satırları sınırlar; bir satır okunabiliyorsa sütunları gizlemez. Bu
-- nedenle hassas sütunlar Data API'nin doğrudan SELECT yetkisinden çıkarılır
-- ve yalnız dar, kimliği doğrulayan RPC üzerinden projekte edilir.

revoke select on table public.profiles from public, anon, authenticated;

do $$
declare
  safe_columns text;
begin
  select string_agg(format('%I', column_name), ', ' order by ordinal_position)
    into safe_columns
    from information_schema.columns
   where table_schema = 'public'
     and table_name = 'profiles'
     and column_name not in (
       'national_id',
       'phone',
       'height_cm',
       'weight_kg'
     );

  if safe_columns is null then
    raise exception 'profiles güvenli sütun listesi üretilemedi';
  end if;

  execute format(
    'grant select (%s) on table public.profiles to authenticated',
    safe_columns
  );
end;
$$;

drop function if exists public.profile_private_projection(uuid);
create function public.profile_private_projection(p_profile_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  viewer uuid := auth.uid();
  target public.profiles%rowtype;
  is_minor boolean;
begin
  if viewer is null then
    raise exception 'Oturum gerekli' using errcode = '42501';
  end if;

  select * into target
    from public.profiles
   where id = p_profile_id;

  if not found then
    return null;
  end if;

  is_minor := exists (
    select 1
      from public.athletes a
     where a.profile_id = p_profile_id
       and (
         (a.birth_date is not null and
          a.birth_date > ((now() at time zone 'Europe/Istanbul')::date - interval '18 years')::date)
         or exists (
           select 1 from public.guardians g where g.athlete_id = a.id
         )
       )
  );

  return jsonb_build_object(
    'phone', case
      when viewer = p_profile_id then target.phone
      when not is_minor and not target.phone_hidden then target.phone
      else null
    end,
    'height_cm', case
      when viewer = p_profile_id or not is_minor then target.height_cm
      else null
    end,
    'weight_kg', case
      when viewer = p_profile_id or not is_minor then target.weight_kg
      else null
    end
  );
end;
$$;

revoke all on function public.profile_private_projection(uuid) from public, anon;
grant execute on function public.profile_private_projection(uuid) to authenticated;

comment on function public.profile_private_projection(uuid) is
  'Telefonu görünürlük tercihine göre, çocuk fiziksel verilerini yalnız sahibine projekte eder.';
