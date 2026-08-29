-- SwanSport — 0033: etkinlik katılım onayı (RSVP)
-- Sporcu kendi katılım kararını verir; antrenör yalnızca toplu özeti görür.

create table if not exists public.event_rsvps (
  event_id    uuid not null references public.events(id) on delete cascade,
  athlete_id  uuid not null references public.athletes(id) on delete cascade,
  status      text not null check (status in ('attending', 'uncertain', 'unavailable')),
  note        text,
  updated_at  timestamptz not null default now(),
  primary key (event_id, athlete_id)
);

create index if not exists idx_event_rsvps_event on public.event_rsvps(event_id);
alter table public.event_rsvps enable row level security;
revoke all on table public.event_rsvps from public, anon, authenticated;

create or replace function public.set_event_rsvp(
  p_event uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_athlete uuid;
  v_club uuid;
begin
  if p_status not in ('attending', 'uncertain', 'unavailable') then
    raise exception 'Geçersiz katılım durumu';
  end if;

  select e.club_id into v_club from public.events e where e.id = p_event;
  if v_club is null then raise exception 'Etkinlik bulunamadı'; end if;

  select a.id into v_athlete
    from public.athletes a
   where a.club_id = v_club and a.profile_id = auth.uid()
   limit 1;
  if v_athlete is null then raise exception 'Bu etkinlik için katılım onayı veremezsin'; end if;

  insert into public.event_rsvps(event_id, athlete_id, status, note, updated_at)
  values (p_event, v_athlete, p_status, nullif(trim(p_note), ''), now())
  on conflict (event_id, athlete_id) do update
    set status = excluded.status, note = excluded.note, updated_at = now();
end;
$$;

create or replace function public.my_event_rsvp(p_event uuid)
returns table(status text, note text, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.status, r.note, r.updated_at
    from public.event_rsvps r
    join public.athletes a on a.id = r.athlete_id
   where r.event_id = p_event and a.profile_id = auth.uid()
   limit 1;
$$;

create or replace function public.event_rsvp_summary(p_event uuid)
returns table(attending int, uncertain int, unavailable int)
language plpgsql stable security definer set search_path = public as $$
declare v_club uuid;
begin
  select club_id into v_club from public.events where id = p_event;
  if v_club is null or not public.is_club_staff(v_club) then
    raise exception 'Yetkisiz';
  end if;
  return query select
    count(*) filter (where r.status = 'attending')::int,
    count(*) filter (where r.status = 'uncertain')::int,
    count(*) filter (where r.status = 'unavailable')::int
  from public.event_rsvps r where r.event_id = p_event;
end;
$$;

revoke all on function public.set_event_rsvp(uuid, text, text) from public, anon;
revoke all on function public.my_event_rsvp(uuid) from public, anon;
revoke all on function public.event_rsvp_summary(uuid) from public, anon;
grant execute on function public.set_event_rsvp(uuid, text, text) to authenticated;
grant execute on function public.my_event_rsvp(uuid) to authenticated;
grant execute on function public.event_rsvp_summary(uuid) to authenticated;
