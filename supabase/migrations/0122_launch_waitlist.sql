set local lock_timeout = '15s';

create table if not exists public.launch_waitlist (
  id uuid primary key default gen_random_uuid(),
  email text unique not null check (
    email = lower(trim(email))
    and length(email) between 5 and 254
    and email ~ '^[^\s@]+@[^\s@]+\.[^\s@]+$'
  ),
  role text not null default 'athlete' check (
    role in ('athlete', 'coach', 'club_admin', 'guardian', 'referee')
  ),
  sport_code text check (sport_code is null or length(trim(sport_code)) between 1 and 64),
  club_or_city text check (club_or_city is null or length(trim(club_or_city)) between 1 and 120),
  source text not null default 'swansport.com.tr' check (length(trim(source)) between 1 and 80),
  notified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists launch_waitlist_created_idx
  on public.launch_waitlist(created_at desc, id desc);

alter table public.launch_waitlist enable row level security;
revoke all on public.launch_waitlist from public, anon, authenticated;
grant select, update, delete on public.launch_waitlist to authenticated;

drop policy if exists launch_waitlist_admin_all on public.launch_waitlist;
create policy launch_waitlist_admin_all on public.launch_waitlist
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

alter table public.platform_settings disable trigger platform_settings_audit;
insert into public.platform_settings(key, value) values
  ('launch_release', '{"status":"coming_soon","eta_label":"Çok Yakında App Store ve Google Play''de","play_store_url":null,"app_store_url":null,"waitlist_enabled":true}')
on conflict (key) do nothing;
alter table public.platform_settings enable trigger platform_settings_audit;

create or replace function public.get_public_platform_config() returns jsonb
language sql stable security invoker set search_path = public, pg_temp as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from public.platform_settings
  where key in ('branding', 'commissions', 'maintenance', 'broadcast_alert', 'kill_switches', 'launch_release');
$$;
revoke all on function public.get_public_platform_config() from public, anon, authenticated;
grant execute on function public.get_public_platform_config() to anon, authenticated;

create or replace function public.join_launch_waitlist(
  p_email text,
  p_role text default 'athlete',
  p_sport_code text default null,
  p_club_or_city text default null,
  p_source text default 'swansport.com.tr'
) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_role text := lower(trim(coalesce(nullif(trim(p_role), ''), 'athlete')));
  v_sport text := nullif(lower(trim(coalesce(p_sport_code, ''))), '');
  v_city text := nullif(trim(coalesce(p_club_or_city, '')), '');
  v_source text := coalesce(nullif(left(trim(coalesce(p_source, '')), 80), ''), 'swansport.com.tr');
  v_existed boolean := false;
  v_total int := 0;
begin
  if length(v_email) < 5 or length(v_email) > 254 or v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' then
    raise exception 'Geçerli bir e-posta adresi girin' using errcode = '22023';
  end if;
  if v_role not in ('athlete', 'coach', 'club_admin', 'guardian', 'referee') then
    raise exception 'Geçersiz rol seçimi' using errcode = '22023';
  end if;
  if v_sport is not null and length(v_sport) > 64 then
    v_sport := left(v_sport, 64);
  end if;
  if v_city is not null and length(v_city) > 120 then
    v_city := left(v_city, 120);
  end if;

  select exists(select 1 from public.launch_waitlist where email = v_email) into v_existed;

  insert into public.launch_waitlist(email, role, sport_code, club_or_city, source, updated_at)
  values (v_email, v_role, v_sport, v_city, v_source, now())
  on conflict (email) do update
    set role = excluded.role,
        sport_code = coalesce(excluded.sport_code, public.launch_waitlist.sport_code),
        club_or_city = coalesce(excluded.club_or_city, public.launch_waitlist.club_or_city),
        source = excluded.source,
        updated_at = now();

  select count(*)::int into v_total from public.launch_waitlist;

  return jsonb_build_object(
    'ok', true,
    'already_registered', v_existed,
    'role', v_role,
    'waitlist_count', v_total
  );
end;
$$;
revoke all on function public.join_launch_waitlist(text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.join_launch_waitlist(text, text, text, text, text) to anon, authenticated;

create or replace function public.public_waitlist_summary() returns jsonb
language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'total_count', count(*)::int,
    'athlete_count', count(*) filter (where role = 'athlete')::int,
    'coach_count', count(*) filter (where role = 'coach')::int,
    'club_count', count(*) filter (where role = 'club_admin')::int,
    'guardian_count', count(*) filter (where role = 'guardian')::int,
    'referee_count', count(*) filter (where role = 'referee')::int
  )
  from public.launch_waitlist;
$$;
revoke all on function public.public_waitlist_summary() from public, anon, authenticated;
grant execute on function public.public_waitlist_summary() to anon, authenticated;

create or replace function public.mark_launch_waitlist_notified(p_emails text[] default null) returns int
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_count int := 0;
begin
  if not coalesce(public.is_platform_admin(), false) then
    raise exception 'Platform administrator required' using errcode = '42501';
  end if;

  if p_emails is null or cardinality(p_emails) = 0 then
    update public.launch_waitlist
       set notified_at = now(),
           updated_at = now()
     where notified_at is null;
  else
    update public.launch_waitlist
       set notified_at = now(),
           updated_at = now()
     where email = any(
       select lower(trim(u))
       from unnest(p_emails) as u
       where u is not null and length(trim(u)) > 0
     );
  end if;

  get diagnostics v_count = row_count;

  if to_regclass('public.platform_audit_logs') is not null then
    insert into public.platform_audit_logs(actor_id, action, entity_type, entity_id, old_state, new_state)
    values (
      auth.uid(),
      'notify',
      'launch_waitlist',
      'batch',
      null,
      jsonb_build_object('notified_count', v_count)
    );
  end if;

  return v_count;
end;
$$;
revoke all on function public.mark_launch_waitlist_notified(text[]) from public, anon, authenticated;
grant execute on function public.mark_launch_waitlist_notified(text[]) to authenticated;

notify pgrst, 'reload schema';

