-- ---------------------------------------------------------------------------
-- 0039 — Halı sahada "bu saati istiyorum" bildirimi
--
-- Gerçek boşluk: müşteri telefonla arar, görevli sözlü "tamam" der, sonra
-- uygulamayı açıp işaretlemeyi unutabilir — pano bayatlar.
--
-- Çözüm İKİ TARAFLI KİLİTLİ REZERVASYON DEĞİL: oyuncu bir saati "istiyorum"
-- diye işaretler, sahanın yöneticilerine bildirim gider, yönetici telefonla
-- konuşur ve anlaşırlarsa ZATEN VAR OLAN doluluk işaretleme akışıyla
-- (0038'deki turf_occupancy) hücreyi kendisi kapatır. Uygulama hiçbir zaman
-- "onaylandı" demiyor — son söz hâlâ yönetici. Bu yüzden claim_slot gibi bir
-- yarış durumu koruması gerekmiyor: kilitleyen bir şey yok, yalnızca haber.
-- ---------------------------------------------------------------------------

create table if not exists public.turf_slot_requests (
  id           uuid primary key default gen_random_uuid(),
  field_id     uuid not null references public.turf_fields(id) on delete cascade,
  starts_at    timestamptz not null,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),

  -- Aynı kişi aynı hücreye tekrar tekrar dokununca yöneticiye bildirim
  -- selı gitmesin diye.
  constraint turf_slot_request_unique unique (field_id, starts_at, requester_id)
);

alter table public.turf_slot_requests enable row level security;

drop policy if exists "turf_slot_request_self" on public.turf_slot_requests;
create policy "turf_slot_request_self" on public.turf_slot_requests
  for select to authenticated
  using (requester_id = auth.uid() or public.is_turf_manager(field_id));

-- Yazma yok — tamamen RPC'den geçiyor, aşağıda.

create or replace function public.request_turf_slot(p_field uuid, p_starts_at timestamptz)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_field           record;
  v_requester_name  text;
  v_new             boolean;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_field from public.turf_fields where id = p_field and active;
  if v_field is null then raise exception 'Saha bulunamadı'; end if;

  insert into public.turf_slot_requests (field_id, starts_at, requester_id)
  values (p_field, p_starts_at, auth.uid())
  on conflict (field_id, starts_at, requester_id) do nothing
  returning true into v_new;

  -- Zaten istemiş: sessizce çık, ikinci bir bildirim atma.
  if v_new is not true then return; end if;

  select coalesce(full_name, 'Biri') into v_requester_name
    from public.profiles where id = auth.uid();

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  select m.profile_id, 'turf_slot_request',
         v_requester_name || ' bir saat istiyor',
         v_field.venue_name || ' ' || v_field.name || ' · ' ||
           to_char(p_starts_at at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') ||
           ' · konuşup anlaşırsan uygulamadan dolu işaretlemeyi unutma',
         auth.uid(), 'turf_field', p_field
    from public.turf_field_managers m
   where m.field_id = p_field and m.status = 'active';
end; $$;

revoke execute on function public.request_turf_slot(uuid, timestamptz) from public, anon;

-- `turf_occupancy_grid`'e `requested_by_me` eklendi: dönüş tipi değiştiği
-- için `create or replace` yetmiyor (Postgres imza aynıysa bile RETURNS
-- TABLE kolonlarını değiştirmeyi reddediyor) — önce düşürülüyor.
drop function if exists public.turf_occupancy_grid(uuid, int);

create function public.turf_occupancy_grid(p_field uuid, p_days int default 7)
returns table (
  starts_at        timestamptz,
  occupied         boolean,
  note             text,
  requested_by_me  boolean
)
language sql stable security definer set search_path = public as $$
  with field as (select * from public.turf_fields where id = p_field and active),
  slots as (
    select (d.day + (h.hr || ' hours')::interval) as local_starts_at
      from field f,
           lateral generate_series(
             date_trunc('day', now() at time zone 'Europe/Istanbul'),
             date_trunc('day', now() at time zone 'Europe/Istanbul')
               + ((greatest(p_days, 1) - 1) || ' days')::interval,
             interval '1 day') as d(day),
           lateral generate_series(
             extract(hour from f.opens_at)::int,
             extract(hour from f.closes_at)::int - 1) as h(hr)
  )
  select
    (s.local_starts_at at time zone 'Europe/Istanbul'),
    (o.id is not null),
    o.note,
    exists (
      select 1 from public.turf_slot_requests r
       where r.field_id = p_field
         and r.starts_at = (s.local_starts_at at time zone 'Europe/Istanbul')
         and r.requester_id = auth.uid()
    )
    from slots s
    left join public.turf_occupancy o
      on o.field_id = p_field
     and o.starts_at = (s.local_starts_at at time zone 'Europe/Istanbul')
   where (s.local_starts_at at time zone 'Europe/Istanbul') >= now()
   order by 1;
$$;

-- push_route: partner_request'teki gibi genel bir gelen kutusuna
-- yönlendiriyor, spesifik saatin derinliğine inmiyor (MVP).
create or replace function public.push_route(p_kind text, p_entity text)
returns text language sql immutable as $$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    else '/bildirimler'
  end;
$$;
