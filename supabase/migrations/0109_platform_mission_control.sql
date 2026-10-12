set local lock_timeout = '15s';

-- Public configuration only: NEVER put credentials or private data here.
-- These values do not themselves enforce signup/payment/marketplace gates.
create table if not exists public.platform_settings (
  key text primary key,
  value jsonb not null check (jsonb_typeof(value) = 'object'),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);
create table if not exists public.platform_plans (
  id uuid primary key default gen_random_uuid(),
  target text not null check (target in ('club', 'athlete')),
  code text unique not null check (length(trim(code)) > 0),
  name text not null check (length(trim(name)) > 0),
  badge text,
  price_monthly numeric not null default 0 check (
    price_monthly >= 0 and price_monthly::text not in ('NaN', 'Infinity', '-Infinity')),
  price_yearly numeric not null default 0 check (
    price_yearly >= 0 and price_yearly::text not in ('NaN', 'Infinity', '-Infinity')),
  max_athletes int check (max_athletes >= 0),
  features jsonb not null default '[]'::jsonb check (jsonb_typeof(features) = 'array'),
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.platform_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  old_state jsonb,
  new_state jsonb,
  created_at timestamptz not null default now()
);
create index if not exists platform_audit_logs_created_idx
  on public.platform_audit_logs(created_at desc, id desc);

insert into public.platform_settings(key, value) values
 ('branding', '{"app_name":"SwanSport","logo_url":null,"tagline":"Sporun Dijital Buluşma Noktası","support_email":"destek@swansport.com.tr"}'),
 ('commissions', '{"marketplace_rate":5.0,"court_rate":3.0,"dues_fee_fixed":10.0,"dues_fee_rate":1.5}'),
 ('maintenance', '{"enabled":false,"message":"SwanSport kısa süreli bakımdadır."}'),
 ('broadcast_alert', '{"enabled":false,"severity":"info","title":"","message":""}'),
 ('kill_switches', '{"disable_signups":false,"disable_payments":false,"disable_marketplace":false}')
on conflict (key) do nothing;
-- Annual prices were not specified: retain the requested schema default (0).
insert into public.platform_plans(target, code, name, price_monthly, max_athletes, sort_order) values
 ('club', 'starter', 'Kulüp Başlangıç', 0, 50, 0),
 ('club', 'pro', 'Kulüp Pro', 1490, 200, 1),
 ('club', 'academy', 'Kulüp Akademi', 3990, null, 2),
 ('athlete', 'athlete_pro', 'Swan Pro Sporcu', 79, null, 3)
on conflict (code) do nothing;

alter table public.platform_settings enable row level security;
alter table public.platform_plans enable row level security;
alter table public.platform_audit_logs enable row level security;
revoke all on public.platform_settings, public.platform_plans, public.platform_audit_logs
  from public, anon, authenticated;
grant select on public.platform_settings, public.platform_plans to anon, authenticated;
grant insert, update, delete on public.platform_settings, public.platform_plans to authenticated;
grant select on public.platform_audit_logs to authenticated;

drop policy if exists platform_settings_read on public.platform_settings;
create policy platform_settings_read on public.platform_settings for select to anon, authenticated using (true);
drop policy if exists platform_settings_write on public.platform_settings;
create policy platform_settings_write on public.platform_settings for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());
drop policy if exists platform_plans_read on public.platform_plans;
create policy platform_plans_read on public.platform_plans for select to anon, authenticated
  using (is_active or public.is_platform_admin());
drop policy if exists platform_plans_write on public.platform_plans;
create policy platform_plans_write on public.platform_plans for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());
drop policy if exists platform_audit_read on public.platform_audit_logs;
create policy platform_audit_read on public.platform_audit_logs for select to authenticated
  using (public.is_platform_admin());

-- Server-owned attribution/timestamps; direct table writes cannot forge them.
create or replace function public._platform_stamp() returns trigger
language plpgsql set search_path = public, pg_temp as $$
begin
  new.updated_at := now();
  if tg_table_name = 'platform_settings' then
    new.updated_by := auth.uid();
  elsif tg_op = 'UPDATE' then
    new.created_at := old.created_at;
  else
    new.created_at := now();
  end if;
  return new;
end;
$$;
-- Trigger auditing covers both RPCs and permitted direct admin writes.
create or replace function public._platform_audit() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
declare prior jsonb; next_state jsonb;
begin
  if not coalesce(public.is_platform_admin(), false) then
    raise exception 'Platform administrator required' using errcode = '42501';
  end if;
  if tg_op <> 'INSERT' then prior := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then next_state := to_jsonb(new); end if;
  insert into public.platform_audit_logs(actor_id, action, entity_type, entity_id, old_state, new_state)
  values (auth.uid(), lower(tg_op), tg_table_name,
    coalesce(next_state, prior)->>case when tg_table_name = 'platform_settings' then 'key' else 'id' end,
    prior, next_state);
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function public._platform_stamp(), public._platform_audit() from public, anon, authenticated;
drop trigger if exists platform_settings_stamp on public.platform_settings;
create trigger platform_settings_stamp before insert or update on public.platform_settings
  for each row execute function public._platform_stamp();
drop trigger if exists platform_plans_stamp on public.platform_plans;
create trigger platform_plans_stamp before insert or update on public.platform_plans
  for each row execute function public._platform_stamp();
drop trigger if exists platform_settings_audit on public.platform_settings;
create trigger platform_settings_audit after insert or update or delete on public.platform_settings
  for each row execute function public._platform_audit();
drop trigger if exists platform_plans_audit on public.platform_plans;
create trigger platform_plans_audit after insert or update or delete on public.platform_plans
  for each row execute function public._platform_audit();

create or replace function public.get_public_platform_config() returns jsonb
language sql stable security invoker set search_path = public, pg_temp as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from public.platform_settings
  where key in ('branding', 'commissions', 'maintenance', 'broadcast_alert', 'kill_switches');
$$;
create or replace function public.update_platform_setting(p_key text, p_value jsonb) returns jsonb
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not coalesce(public.is_platform_admin(), false) then
    raise exception 'Platform administrator required' using errcode = '42501';
  end if;
  if p_value is null or jsonb_typeof(p_value) <> 'object' then
    raise exception 'Setting value must be an object' using errcode = '22023';
  end if;
  update public.platform_settings set value = p_value where key = p_key;
  if not found then raise exception 'Unknown platform setting' using errcode = '22023'; end if;
  return p_value;
end;
$$;
revoke all on function public.get_public_platform_config(), public.update_platform_setting(text, jsonb)
  from public, anon, authenticated;
grant execute on function public.get_public_platform_config() to anon, authenticated;
grant execute on function public.update_platform_setting(text, jsonb) to authenticated;
