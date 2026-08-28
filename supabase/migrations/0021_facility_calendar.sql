-- =============================================================================
-- SwanSport — TESİS ↔ TAKVİM BAĞLANTISI
--
-- Tesis modülünün tek başına değeri yoktu: doluluk oranı elle giriliyordu ve
-- kimse güncellemediği için yanlış bilgi gösteriyordu. Asıl işe yarayan şey,
-- tesisi takvime bağlamak:
--   • Aynı salona iki antrenman yazılırsa uyarı verilir (çakışma).
--   • Doluluk elle değil, o haftanın programından hesaplanır.
--   • Her salonun kendi programı görülebilir.
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ETKİNLİĞE TESİS ALANI
--
-- `place` (düz metin) olduğu gibi kalıyor: eski kayıtlar bozulmasın ve tesis
-- kaydı olmayan yerler ("Deplasman", "Rakip saha") yazılabilsin.
-- ---------------------------------------------------------------------------
alter table public.events
  add column if not exists facility_id uuid
    references public.facilities(id) on delete set null;

create index if not exists idx_events_facility
  on public.events (facility_id, starts_at);


-- ---------------------------------------------------------------------------
-- 2) ÇAKIŞMA KONTROLÜ
--
-- Bitiş saati boş olan etkinlikler için varsayılan 90 dakika kabul edilir —
-- aksi halde süresi bilinmeyen bir antrenman hiçbir şeyle çakışmaz görünürdü.
-- ---------------------------------------------------------------------------
create or replace function public.facility_conflicts(
  p_facility uuid,
  p_start    timestamptz,
  p_end      timestamptz default null,
  p_exclude  uuid default null)
returns table (
  id uuid, title text, starts_at timestamptz, ends_at timestamptz, team_name text
)
language sql stable security definer set search_path = public as $$
  select e.id, e.title, e.starts_at,
         coalesce(e.ends_at, e.starts_at + interval '90 minutes'),
         t.name
    from public.events e
    left join public.teams t on t.id = e.team_id
   where e.facility_id = p_facility
     and (p_exclude is null or e.id <> p_exclude)
     and public.is_club_member(e.club_id)
     -- Aralıklar kesişiyor mu: (A_baş < B_bit) ve (B_baş < A_bit)
     and e.starts_at < coalesce(p_end, p_start + interval '90 minutes')
     and coalesce(e.ends_at, e.starts_at + interval '90 minutes') > p_start
   order by e.starts_at;
$$;


-- ---------------------------------------------------------------------------
-- 3) TESİS PROGRAMI
-- ---------------------------------------------------------------------------
create or replace function public.facility_schedule(
  p_facility uuid, p_days int default 7)
returns table (
  id uuid, title text, kind text, starts_at timestamptz,
  ends_at timestamptz, team_name text
)
language sql stable security definer set search_path = public as $$
  select e.id, e.title, e.kind::text, e.starts_at,
         coalesce(e.ends_at, e.starts_at + interval '90 minutes'), t.name
    from public.events e
    left join public.teams t on t.id = e.team_id
   where e.facility_id = p_facility
     and public.is_club_member(e.club_id)
     and e.starts_at >= date_trunc('day', now())
     and e.starts_at < date_trunc('day', now()) + (greatest(p_days,1) || ' days')::interval
   order by e.starts_at;
$$;


-- ---------------------------------------------------------------------------
-- 4) HESAPLANAN DOLULUK
--
-- Elle girilen `occupancy` yerine önümüzdeki 7 günün programından türetilir:
-- kaç etkinlik, toplam kaç saat ve haftalık kullanılabilir saate (varsayılan
-- 7×4 = 28 saat) oranı.
-- ---------------------------------------------------------------------------
create or replace function public.facility_load(p_club uuid)
returns table (
  facility_id  uuid,
  name         text,
  kind         text,
  status       text,
  event_count  int,
  busy_minutes int,
  load_percent int,
  next_starts  timestamptz,
  next_title   text
)
language sql stable security definer set search_path = public as $$
  with win as (
    select date_trunc('day', now()) as t0,
           date_trunc('day', now()) + interval '7 days' as t1
  ),
  ev as (
    select e.facility_id,
           count(*)::int as n,
           coalesce(sum(extract(epoch from
             (coalesce(e.ends_at, e.starts_at + interval '90 minutes')
              - e.starts_at)) / 60), 0)::int as mins
      from public.events e, win w
     where e.facility_id is not null
       and e.starts_at >= w.t0 and e.starts_at < w.t1
     group by e.facility_id
  )
  select
    f.id, f.name, f.kind, f.status,
    coalesce(ev.n, 0),
    coalesce(ev.mins, 0),
    -- 28 saat = haftada 7 gün × 4 saat kullanılabilir varsayımı
    least(100, round(coalesce(ev.mins, 0) / (28.0 * 60) * 100))::int,
    (select e2.starts_at from public.events e2
      where e2.facility_id = f.id and e2.starts_at >= now()
      order by e2.starts_at limit 1),
    (select e2.title from public.events e2
      where e2.facility_id = f.id and e2.starts_at >= now()
      order by e2.starts_at limit 1)
  from public.facilities f
  left join ev on ev.facility_id = f.id
  where f.club_id = p_club
    and public.is_club_member(p_club)
  order by f.name;
$$;


-- ---------------------------------------------------------------------------
-- 5) TESİSLİ ETKİNLİK OLUŞTURMA
--
-- Çakışma varsa engellemez, uyarı sayısını döndürür: kulüp bilerek üst üste
-- iki grup çalıştırmak isteyebilir. Karar kullanıcıda, bilgi bizde.
-- ---------------------------------------------------------------------------
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
declare v_id uuid;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  insert into public.events
    (club_id, team_id, title, place, kind, starts_at, ends_at, facility_id)
  values (
    p_club, p_team, p_title,
    -- Tesis seçildiyse yer adı ondan gelir; yoksa serbest metin kullanılır.
    coalesce(nullif(p_place, ''),
             (select f.name from public.facilities f where f.id = p_facility)),
    p_kind::public.event_kind, p_starts, p_ends, p_facility)
  returning id into v_id;

  return v_id;
end; $$;
