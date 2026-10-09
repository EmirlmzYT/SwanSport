-- =============================================================================
-- SwanSport — ETKİNLİK KULÜP AİDİYETİ VE BÜTÜNLÜK GÜVENCESİ
--
-- Etkinlik ve seri oluştururken tesis (facility_id) ve takım (team_id)
-- alanlarının etkinliğin ait olduğu kulübe (club_id) ait olduğunu zorunlu kılar.
-- Hem RPC düzeyinde hem de doğrudan yazmalara karşı trigger düzeyinde doğrulanır.
-- Tesis ve takım isteğe bağlı (nullable/optional) kalır.
-- =============================================================================

-- 1) TRIGGER DÜZEYİNDE KULÜP BÜTÜNLÜK KONTROLÜ
create or replace function public.check_event_club_integrity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Tesis seçilmişse kulübe ait olmalıdır
  if new.facility_id is not null then
    if not exists (
      select 1 from public.facilities f
       where f.id = new.facility_id and f.club_id = new.club_id
    ) then
      raise exception 'Seçilen tesis bu kulübe ait değil (facility_id: %, club_id: %)', new.facility_id, new.club_id;
    end if;
  end if;

  -- Takım seçilmişse kulübe ait olmalıdır
  if new.team_id is not null then
    if not exists (
      select 1 from public.teams t
       where t.id = new.team_id and t.club_id = new.club_id
    ) then
      raise exception 'Seçilen takım bu kulübe ait değil (team_id: %, club_id: %)', new.team_id, new.club_id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_check_event_club_integrity on public.events;
create trigger trg_check_event_club_integrity
  before insert or update on public.events
  for each row execute function public.check_event_club_integrity();


-- 2) RPC: create_event (0021 güncellemesi)
create or replace function public.create_event(
  p_club     uuid,
  p_title    text,
  p_kind     text,
  p_starts   timestamptz,
  p_ends     timestamptz default null,
  p_facility uuid default null,
  p_place    text default null,
  p_team     uuid default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id    uuid;
  v_place text;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  -- Tesis seçilmişse bu kulübe ait olduğu doğrulanır
  if p_facility is not null then
    select f.name into v_place
      from public.facilities f
     where f.id = p_facility and f.club_id = p_club;

    if v_place is null then
      raise exception 'Seçilen tesis bu kulübe ait değil';
    end if;
  end if;

  -- Takım seçilmişse bu kulübe ait olduğu doğrulanır
  if p_team is not null then
    if not exists (select 1 from public.teams t where t.id = p_team and t.club_id = p_club) then
      raise exception 'Seçilen takım bu kulübe ait değil';
    end if;
  end if;

  insert into public.events
    (club_id, team_id, title, place, kind, starts_at, ends_at, facility_id)
  values (
    p_club, p_team, p_title,
    coalesce(nullif(p_place, ''), v_place),
    p_kind::public.event_kind, p_starts, p_ends, p_facility)
  returning id into v_id;

  return v_id;
end; $$;

revoke execute on function public.create_event(uuid, text, text, timestamptz, timestamptz, uuid, text, uuid) from public, anon;
grant execute on function public.create_event(uuid, text, text, timestamptz, timestamptz, uuid, text, uuid) to authenticated;


-- 3) RPC: create_event_series (0022 güncellemesi)
create or replace function public.create_event_series(
  p_club     uuid,
  p_title    text,
  p_kind     text,
  p_from     date,
  p_until    date,
  p_hour     int,
  p_minute   int,
  p_minutes  int default 90,
  p_weekdays int[] default array[1,3,5],
  p_facility uuid default null,
  p_place    text default null,
  p_team     uuid default null)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_series uuid := gen_random_uuid();
  v_count  int  := 0;
  v_day    date;
  v_start  timestamptz;
  v_place  text;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  if p_until < p_from then
    raise exception 'Bitiş tarihi başlangıçtan önce olamaz';
  end if;

  if p_until - p_from > 800 then
    raise exception 'Seri en fazla ~2 yıl olabilir';
  end if;

  -- Tesis seçilmişse kulüp kontrolü ve yer adı türetme
  if p_facility is not null then
    select f.name into v_place
      from public.facilities f
     where f.id = p_facility and f.club_id = p_club;

    if v_place is null then
      raise exception 'Seçilen tesis bu kulübe ait değil';
    end if;
  end if;

  -- Takım seçilmişse kulüp kontrolü
  if p_team is not null then
    if not exists (select 1 from public.teams t where t.id = p_team and t.club_id = p_club) then
      raise exception 'Seçilen takım bu kulübe ait değil';
    end if;
  end if;

  v_place := coalesce(nullif(p_place, ''), v_place);

  v_day := p_from;
  while v_day <= p_until loop
    if extract(isodow from v_day)::int = any(p_weekdays) then
      v_start := (v_day + make_time(
                    least(greatest(p_hour, 0), 23),
                    least(greatest(p_minute, 0), 59), 0))
                 at time zone 'Europe/Istanbul';

      insert into public.events
        (club_id, team_id, title, place, kind, starts_at, ends_at,
         facility_id, series_id)
      values (p_club, p_team, p_title, v_place, p_kind::public.event_kind,
              v_start, v_start + (p_minutes || ' minutes')::interval,
              p_facility, v_series);

      v_count := v_count + 1;
    end if;
    v_day := v_day + 1;
  end loop;

  return v_count;
end; $$;

revoke execute on function public.create_event_series(uuid, text, text, date, date, int, int, int, int[], uuid, text, uuid) from public, anon;
grant execute on function public.create_event_series(uuid, text, text, date, date, int, int, int, int[], uuid, text, uuid) to authenticated;
