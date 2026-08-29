-- SwanSport — 0032: yoklama denetim izi
--
-- Yoklama, kulübün operasyonel kaydıdır. Bir hücre daha sonra düzeltildiğinde
-- önceki değer ve işlemi yapan kişi kaybolmamalı. Kayıt tetikleyiciyle tutulur;
-- bu sayede mobil, konsol ve gelecekteki istemciler aynı izi üretir.

create table if not exists public.attendance_audit_log (
  id               uuid primary key default gen_random_uuid(),
  club_id          uuid not null references public.clubs(id) on delete cascade,
  event_id         uuid references public.events(id) on delete set null,
  athlete_id       uuid references public.athletes(id) on delete set null,
  previous_status  text,
  status           text not null,
  actor_profile_id uuid,
  created_at       timestamptz not null default now()
);

create index if not exists idx_attendance_audit_club_created
  on public.attendance_audit_log (club_id, created_at desc, id desc);

alter table public.attendance_audit_log enable row level security;

-- Bu tablo istemciden yazılmaz veya doğrudan okunmaz. Yazmayı tetikleyici,
-- okumayı ise aşağıdaki yetki kontrollü RPC yapar.
revoke all on table public.attendance_audit_log from public, anon, authenticated;

create or replace function public.log_attendance_change()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and new.status is not distinct from old.status then
    return new;
  end if;

  insert into public.attendance_audit_log (
    club_id, event_id, athlete_id, previous_status, status, actor_profile_id
  )
  values (
    new.club_id,
    new.event_id,
    new.athlete_id,
    case when tg_op = 'INSERT' then null else old.status::text end,
    new.status::text,
    auth.uid()
  );

  return new;
end;
$$;

drop trigger if exists trg_attendance_audit on public.attendance;
create trigger trg_attendance_audit
  after insert or update of status on public.attendance
  for each row execute function public.log_attendance_change();

create or replace function public.attendance_audit(
  p_club uuid,
  p_limit int default 50
)
returns table (
  id uuid,
  event_id uuid,
  event_title text,
  athlete_id uuid,
  athlete_name text,
  previous_status text,
  status text,
  actor_name text,
  created_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  return query
    select l.id,
           l.event_id,
           coalesce(e.title, 'Silinmiş etkinlik'),
           l.athlete_id,
           nullif(concat_ws(' ', a.first_name, a.last_name), ''),
           l.previous_status,
           l.status,
           nullif(p.full_name, ''),
           l.created_at
      from public.attendance_audit_log l
      left join public.events e on e.id = l.event_id
      left join public.athletes a on a.id = l.athlete_id
      left join public.profiles p on p.id = l.actor_profile_id
     where l.club_id = p_club
     order by l.created_at desc, l.id desc
     limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$$;

revoke execute on function public.attendance_audit(uuid, int) from public, anon;
grant execute on function public.attendance_audit(uuid, int) to authenticated;
