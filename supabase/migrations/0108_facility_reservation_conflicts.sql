-- =============================================================================
-- SwanSport — Tesis rezervasyonları ve birleşik çakışma denetimi
-- =============================================================================
set local lock_timeout = '15s';

-- Eski etkinlik kayıtları için iptal bilgisi yoktu. Varsayılan, mevcut
-- takvim davranışını koruyan scheduled'dır; yalnız cancelled çakışmaz.
alter table public.events
  add column if not exists status text not null default 'scheduled';

alter table public.events
  drop constraint if exists events_status_check;
alter table public.events
  add constraint events_status_check
  check (status in ('scheduled', 'completed', 'cancelled'));

create table if not exists public.facility_reservations (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  facility_id uuid not null references public.facilities(id) on delete cascade,
  title text not null,
  kind text not null default 'rental'
    check (kind in ('rental', 'maintenance', 'private_lesson', 'club_event', 'other')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  constraint chk_res_interval check (ends_at > starts_at),
  reserved_by_name text,
  reserved_by_phone text,
  reserved_by_profile_id uuid references public.profiles(id) on delete set null,
  status text not null default 'confirmed'
    check (status in ('pending', 'confirmed', 'cancelled', 'completed')),
  fee numeric(12,2) not null default 0,
  invoice_id uuid references public.invoices(id) on delete set null,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_facility_reservations_facility_starts
  on public.facility_reservations (facility_id, starts_at);
create index if not exists idx_facility_reservations_club_status
  on public.facility_reservations (club_id, status);

alter table public.facility_reservations enable row level security;
grant select, insert, update, delete on public.facility_reservations to authenticated;

drop policy if exists facility_reservations_read on public.facility_reservations;
create policy facility_reservations_read on public.facility_reservations
  for select to authenticated
  using (
    public.is_club_member(club_id)
    and status in ('pending', 'confirmed')
  );

drop policy if exists facility_reservations_staff_manage on public.facility_reservations;
create policy facility_reservations_staff_manage on public.facility_reservations
  for all to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

drop trigger if exists trg_facility_reservations_updated on public.facility_reservations;
create trigger trg_facility_reservations_updated
  before update on public.facility_reservations
  for each row execute function public.set_updated_at();

-- Dönüş tipi ve imza değiştiği için eski dört parametreli sürüm kalmamalı.
drop function if exists public.facility_conflicts(uuid, timestamptz, timestamptz, uuid);

create or replace function public.facility_conflicts(
  p_facility uuid,
  p_start timestamptz,
  p_end timestamptz default null,
  p_exclude uuid default null,
  p_team uuid default null
)
returns table (
  conflict_source text,
  id uuid,
  title text,
  kind text,
  starts_at timestamptz,
  ends_at timestamptz,
  team_name text
)
language sql stable security definer set search_path = public as $$
  select 'event'::text,
         e.id,
         e.title,
         e.kind::text,
         e.starts_at,
         coalesce(e.ends_at, e.starts_at + interval '90 minutes'),
         t.name
    from public.events e
    left join public.teams t on t.id = e.team_id
   where (e.facility_id = p_facility or (p_team is not null and e.team_id = p_team))
     and e.status <> 'cancelled'
     and (p_exclude is null or e.id <> p_exclude)
     and public.is_club_member(e.club_id)
     and e.starts_at < coalesce(p_end, p_start + interval '90 minutes')
     and coalesce(e.ends_at, e.starts_at + interval '90 minutes') > p_start
  union all
  select 'reservation'::text,
         r.id,
         r.title,
         r.kind,
         r.starts_at,
         r.ends_at,
         null::text
    from public.facility_reservations r
   where r.facility_id = p_facility
     and r.status in ('pending', 'confirmed')
     and (p_exclude is null or r.id <> p_exclude)
     and public.is_club_member(r.club_id)
     and r.starts_at < coalesce(p_end, p_start + interval '90 minutes')
     and r.ends_at > p_start
  order by 5;
$$;

revoke all on function public.facility_conflicts(uuid, timestamptz, timestamptz, uuid, uuid) from public, anon;
grant execute on function public.facility_conflicts(uuid, timestamptz, timestamptz, uuid, uuid) to authenticated;

create or replace function public.create_facility_reservation(
  p_club uuid,
  p_facility uuid,
  p_title text,
  p_kind text,
  p_starts timestamptz,
  p_ends timestamptz,
  p_by_name text,
  p_by_phone text,
  p_fee numeric default 0,
  p_notes text default null,
  p_allow_conflict boolean default false
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  if not exists (
    select 1 from public.facilities f where f.id = p_facility and f.club_id = p_club
  ) then
    raise exception 'Tesis bu kulübe ait değil';
  end if;

  if p_ends <= p_starts then
    raise exception 'Bitiş saati başlangıç saatinden sonra olmalı';
  end if;

  if not p_allow_conflict and exists (
    select 1 from public.facility_conflicts(p_facility, p_starts, p_ends)
  ) then
    raise exception 'Seçilen saat aralığında tesis çakışması mevcut';
  end if;

  insert into public.facility_reservations (
    club_id, facility_id, title, kind, starts_at, ends_at,
    reserved_by_name, reserved_by_phone, reserved_by_profile_id,
    status, fee, notes, created_by
  ) values (
    p_club, p_facility, p_title, p_kind, p_starts, p_ends,
    p_by_name, p_by_phone, auth.uid(),
    'confirmed', p_fee, p_notes, auth.uid()
  ) returning id into v_id;

  return v_id;
end;
$$;

create or replace function public.cancel_facility_reservation(p_reservation_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_club uuid;
begin
  select club_id into v_club from public.facility_reservations where id = p_reservation_id;
  if v_club is null or not public.is_club_staff(v_club) then
    raise exception 'Yetkisiz veya rezervasyon bulunamadı';
  end if;

  update public.facility_reservations
     set status = 'cancelled'
   where id = p_reservation_id
     and status <> 'cancelled';
end;
$$;

create or replace function public.facility_load(p_club uuid)
returns table (
  facility_id uuid,
  name text,
  kind text,
  status text,
  event_count int,
  busy_minutes int,
  load_percent int,
  next_starts timestamptz,
  next_title text
)
language sql stable security definer set search_path = public as $$
  with win as (
    select date_trunc('day', now()) as t0,
           date_trunc('day', now()) + interval '7 days' as t1
  ), occupied as (
    select e.facility_id, e.title, e.starts_at,
           coalesce(e.ends_at, e.starts_at + interval '90 minutes') as ends_at
      from public.events e
     where e.facility_id is not null and e.status <> 'cancelled'
    union all
    select r.facility_id, r.title, r.starts_at, r.ends_at
      from public.facility_reservations r
     where r.status = 'confirmed'
  ), load as (
    select o.facility_id,
           count(*)::int as n,
           coalesce(sum(extract(epoch from (least(o.ends_at, w.t1) - greatest(o.starts_at, w.t0))) / 60), 0)::int as mins
      from occupied o cross join win w
     where o.starts_at < w.t1 and o.ends_at > w.t0
     group by o.facility_id
  )
  select f.id, f.name, f.kind, f.status,
         coalesce(l.n, 0), coalesce(l.mins, 0),
         least(100, round(coalesce(l.mins, 0) / (28.0 * 60) * 100))::int,
         (select o.starts_at from occupied o where o.facility_id = f.id and o.starts_at >= now() order by o.starts_at limit 1),
         (select o.title from occupied o where o.facility_id = f.id and o.starts_at >= now() order by o.starts_at limit 1)
    from public.facilities f
    left join load l on l.facility_id = f.id
   where f.club_id = p_club and public.is_club_member(p_club)
   order by f.name;
$$;

revoke all on function public.create_facility_reservation(uuid, uuid, text, text, timestamptz, timestamptz, text, text, numeric, text, boolean) from public, anon;
revoke all on function public.cancel_facility_reservation(uuid) from public, anon;
revoke all on function public.facility_load(uuid) from public, anon;
grant execute on function public.create_facility_reservation(uuid, uuid, text, text, timestamptz, timestamptz, text, text, numeric, text, boolean) to authenticated;
grant execute on function public.cancel_facility_reservation(uuid) to authenticated;
grant execute on function public.facility_load(uuid) to authenticated;

-- 0070'teki mevcut yardım kaydı, artık uygulanan davranışı anlatır.
update public.faq_entries
   set answer = 'Tesis rezervasyonu oluştururken aynı tesis ve saat aralığındaki etkinlikler veya aktif rezervasyonlar denetlenir. Çakışma varsa yetkili kişi uyarıyı görür; gerekirse kaydı bilinçli olarak çakışmaya izin vererek oluşturabilir.'
 where feature = 'facility_conflicts';
