set local lock_timeout = '15s';

-- SwanSport Pro Phase 5 hardening:
-- - keep subscription removal scoped to the authenticated account and app;
-- - expose only professional notification kinds to the Pro inbox;
-- - mark only professional notifications as read.

drop function if exists public.drop_push_subscription(text);
drop function if exists public.drop_push_subscription(text, text);

create function public.drop_push_subscription(
  p_endpoint text,
  p_app_target text default 'social'
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_uid uuid := auth.uid();
  v_target text := lower(coalesce(nullif(trim(p_app_target), ''), 'social'));
begin
  if v_uid is null then
    raise exception 'Cihaz kaydını silmek için oturum gerekli';
  end if;
  if v_target not in ('social', 'pro') then
    raise exception 'Geçersiz hedef uygulama: %', p_app_target;
  end if;

  delete from public.push_subscriptions
  where profile_id = v_uid
    and endpoint = p_endpoint
    and app_target = v_target;
end;
$fn$;

revoke all on function public.drop_push_subscription(text, text)
  from public, anon, authenticated;
grant execute on function public.drop_push_subscription(text, text)
  to authenticated;

create or replace function public.my_pro_notifications(
  p_limit int default 60,
  p_before timestamptz default null
)
returns table(
  id uuid,
  kind text,
  title text,
  body text,
  actor_id uuid,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  select
    n.id,
    n.kind,
    n.title,
    n.body,
    n.actor_id,
    n.entity_type,
    n.entity_id,
    n.read_at,
    n.created_at
  from public.notifications n
  where n.profile_id = auth.uid()
    and public._notification_target_policy(n.kind) in ('pro', 'both')
    and (p_before is null or n.created_at < p_before)
    and (n.kind <> 'match_result' or public._guardian_result_visible(n.entity_id))
    and (n.kind <> 'match_live' or public._match_notice_visible(n.entity_id))
  order by n.created_at desc
  limit least(greatest(coalesce(p_limit, 60), 1), 200)
$fn$;

revoke all on function public.my_pro_notifications(int, timestamptz)
  from public, anon, authenticated;
grant execute on function public.my_pro_notifications(int, timestamptz)
  to authenticated;

create or replace function public.mark_pro_notifications_read(
  p_notification uuid default null
)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_count int;
begin
  if auth.uid() is null then
    raise exception 'Bildirim güncellemek için oturum gerekli';
  end if;

  update public.notifications n
  set read_at = coalesce(n.read_at, clock_timestamp())
  where n.profile_id = auth.uid()
    and public._notification_target_policy(n.kind) in ('pro', 'both')
    and (p_notification is null or n.id = p_notification)
    and (n.kind <> 'match_result' or public._guardian_result_visible(n.entity_id))
    and (n.kind <> 'match_live' or public._match_notice_visible(n.entity_id));

  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

revoke all on function public.mark_pro_notifications_read(uuid)
  from public, anon, authenticated;
grant execute on function public.mark_pro_notifications_read(uuid)
  to authenticated;

-- These helpers are internal policy/route implementation details, not client RPCs.
revoke execute on function public._notification_target_policy(text)
  from public, anon, authenticated;
revoke execute on function public.pro_push_route(text, text)
  from public, anon, authenticated;
