set local lock_timeout = '15s';

-- -----------------------------------------------------------------------------
-- 20261028000000_push_app_target.sql
-- SwanSport Pro Phase 5: Application-targeted push subscriptions and delivery routing.
-- -----------------------------------------------------------------------------

-- 1) push_subscriptions app_target column & revision tracking
alter table public.push_subscriptions
  add column if not exists app_target text not null default 'social'
  check (app_target in ('social', 'pro'));

create or replace function public._push_registration_revision() returns trigger
language plpgsql set search_path=public,pg_temp as $$
begin
  if row(new.profile_id, new.endpoint, new.kind, new.p256dh, new.auth, new.app_target)
    is distinct from row(old.profile_id, old.endpoint, old.kind, old.p256dh, old.auth, old.app_target) then
    new.delivery_revision := old.delivery_revision + 1;
  else
    new.delivery_revision := old.delivery_revision;
  end if;
  return new;
end $$;
revoke all on function public._push_registration_revision() from public, anon, authenticated;

drop trigger if exists push_registration_revision on public.push_subscriptions;
create trigger push_registration_revision before update on public.push_subscriptions
  for each row execute function public._push_registration_revision();

-- 2) push_delivery_attempts app_target immutable column
alter table public.push_delivery_attempts
  add column if not exists app_target text not null default 'social'
  check (app_target in ('social', 'pro'));

-- 3) Central notification target policy (42 kinds + fail-closed default)
create or replace function public._notification_target_policy(p_kind text) returns text
language sql immutable set search_path=public,pg_temp as $$
  select case p_kind
    -- 9 Social-only kinds
    when 'message' then 'social'
    when 'follow' then 'social'
    when 'mention' then 'social'
    when 'post_repost' then 'social'
    when 'post_quote' then 'social'
    when 'partner_request' then 'social'
    when 'partner_request_accepted' then 'social'
    when 'offer' then 'social'
    when 'achievement' then 'social'

    -- 15 Pro-only kinds
    when 'referee_assignment' then 'pro'
    when 'expense_approval' then 'pro'
    when 'expense_rejected' then 'pro'
    when 'commitment_due' then 'pro'
    when 'account_negative' then 'pro'
    when 'bank_unmatched' then 'pro'
    when 'period_closed' then 'pro'
    when 'period_blocked' then 'pro'
    when 'turf_slot_request' then 'pro'
    when 'turf_field' then 'pro'
    when 'turf_manager' then 'pro'
    when 'court_waitlist' then 'pro'
    when 'turf_delegation' then 'pro'
    when 'store_decision' then 'pro'
    when 'moderation' then 'pro'

    -- 18 Transitional both kinds
    when 'match_live' then 'both'
    when 'match_result' then 'both'
    when 'fee' then 'both'
    when 'fee_reminder' then 'both'
    when 'payment' then 'both'
    when 'donation' then 'both'
    when 'attendance' then 'both'
    when 'attendance_reminder' then 'both'
    when 'event' then 'both'
    when 'announcement' then 'both'
    when 'document' then 'both'
    when 'documents' then 'both'
    when 'document_expiry' then 'both'
    when 'support' then 'both'
    when 'eligibility' then 'both'
    when 'training_session' then 'both'
    when 'training_result' then 'both'
    when 'application' then 'both'

    -- Fail-closed default for unknown / null
    else 'social'
  end;
$$;
revoke all on function public._notification_target_policy(text) from public, anon, authenticated;
grant execute on function public._notification_target_policy(text) to authenticated, service_role;

-- 4) Pro push route resolution
create or replace function public.pro_push_route(p_kind text, p_entity text) returns text
language sql immutable set search_path=public,pg_temp as $$
  select case p_kind
    when 'referee_assignment' then '/operasyon/hakem-gorevleri'
    when 'expense_approval' then '/operasyon/muhasebe'
    when 'expense_rejected' then '/operasyon/muhasebe'
    when 'commitment_due' then '/operasyon/mali-taahhutler'
    when 'account_negative' then '/operasyon/muhasebe'
    when 'bank_unmatched' then '/operasyon/banka-mutabakati'
    when 'period_closed' then '/operasyon/donem-kapanisi'
    when 'period_blocked' then '/operasyon/donem-kapanisi'
    when 'turf_slot_request' then '/operasyon/tesis-takvim'
    when 'turf_field' then '/operasyon/tesis'
    when 'turf_manager' then '/operasyon/tesis'
    when 'court_waitlist' then '/operasyon/tesis-takvim'
    when 'turf_delegation' then '/operasyon/tesis-gorevleri'
    when 'training_session' then '/operasyon/antrenmanlar'
    when 'training_result' then '/operasyon/antrenmanlar'
    when 'attendance' then '/operasyon/yoklama'
    when 'attendance_reminder' then '/operasyon/yoklama'
    when 'match_live' then
      case when coalesce(p_entity ~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$', false)
        then '/operasyon/hakem-canli/' || p_entity
        else '/gelen-kutusu'
      end
    when 'match_result' then '/operasyon/federasyon-maclar'
    when 'store_decision' then '/operasyon/platform'
    when 'moderation' then '/operasyon/platform'
    else '/gelen-kutusu'
  end;
$$;
revoke all on function public.pro_push_route(text, text) from public, anon, authenticated;
grant execute on function public.pro_push_route(text, text) to authenticated, service_role;

-- 5) Enqueue per matching application target
create or replace function public.push_on_notification() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  s public.push_subscriptions;
  delivery uuid;
  v_policy text;
begin
  if not coalesce(public._push_delivery_permitted(new), false) then
    return new;
  end if;
  v_policy := public._notification_target_policy(new.kind);
  for s in select * from public.push_subscriptions sub
    where sub.profile_id = new.profile_id
      and (v_policy = 'both' or sub.app_target = v_policy)
  loop
    insert into public.push_delivery_attempts(
      notification_id,
      profile_id,
      subscription_id,
      subscription_revision,
      app_target,
      expires_at
    )
    values(
      new.id,
      new.profile_id,
      s.id,
      s.delivery_revision,
      s.app_target,
      now() + case when new.kind = 'match_live' then interval '60 seconds' else interval '1 day' end
    )
    on conflict(notification_id, subscription_id) do nothing returning id into delivery;
    if delivery is not null then
      perform public._dispatch_push_delivery(delivery);
    end if;
  end loop;
  return new;
end $$;
revoke all on function public.push_on_notification() from public, anon, authenticated;

drop trigger if exists trg_push_on_notification on public.notifications;
create trigger trg_push_on_notification after insert on public.notifications
  for each row execute function public.push_on_notification();

-- 6) Dispatch with app_target revalidation during retry
create or replace function public._dispatch_push_delivery(p_id uuid) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare
  d public.push_delivery_attempts;
  n public.notifications;
  s public.push_subscriptions;
  secret text;
  route text;
  request bigint;
  v_policy text;
begin
  select * into d from public.push_delivery_attempts where id=p_id for update skip locked;
  if not found or d.status not in ('pending', 'retry') or d.next_attempt_at > now() then
    return;
  end if;
  if d.expires_at <= now() then
    update public.push_delivery_attempts set status='expired', updated_at=now() where id=d.id;
    return;
  end if;
  select * into n from public.notifications where id=d.notification_id;
  if not found then
    return;
  end if;
  select * into s from public.push_subscriptions where id=d.subscription_id and profile_id=d.profile_id for share;
  if not found or s.delivery_revision <> d.subscription_revision or not coalesce(public._push_delivery_permitted(n), false) then
    if found and s.app_target <> d.app_target then
      update public.push_delivery_attempts set status='skipped', last_outcome='target_mismatch', updated_at=now() where id=d.id;
      return;
    end if;
    update public.push_delivery_attempts set status='skipped', last_outcome='registration_or_preference_changed', updated_at=now() where id=d.id;
    return;
  end if;
  -- Validate target ownership and policy at time of delivery/retry
  v_policy := public._notification_target_policy(n.kind);
  if s.app_target <> d.app_target or (v_policy <> 'both' and v_policy <> d.app_target) then
    update public.push_delivery_attempts set status='skipped', last_outcome='target_mismatch', updated_at=now() where id=d.id;
    return;
  end if;
  secret := public.push_secret();
  if secret is null or secret = '' then
    update public.push_delivery_attempts set status='failed', last_outcome='configuration_missing', updated_at=now() where id=d.id;
    return;
  end if;

  if d.app_target = 'pro' then
    route := public.pro_push_route(n.kind, n.entity_id::text);
  else
    route := case when n.kind = 'match_result' then '/resmi-sonuc?notification=' || n.id::text
      when n.kind = 'match_live' then public.push_route(n.kind, n.entity_id::text)
      else public.push_route(n.kind, n.entity_type) end;
  end if;

  request := net.http_post(
    url := 'https://swansport.pages.dev/api/push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', secret),
    body := jsonb_build_object(
      'title', n.title,
      'body', coalesce(n.body, ''),
      'url', route,
      'appTarget', d.app_target,
      'subs', jsonb_build_array(jsonb_build_object('kind', s.kind, 'endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth))
    )
  );
  update public.push_delivery_attempts set status='in_flight', attempt_count=attempt_count+1,
    request_id=request, last_attempt_at=now(), updated_at=now(), last_outcome=null where id=d.id;
exception when others then
  update public.push_delivery_attempts set status='failed', last_outcome='enqueue_failed', updated_at=now() where id=p_id;
end $$;
revoke all on function public._dispatch_push_delivery(uuid) from public, anon, authenticated;

-- 7) Single canonical register_push_subscription with p_app_target
drop function if exists public.register_push_subscription(text, text, text, text, text);
drop function if exists public.register_push_subscription(text, text, text, text, text, text);

create or replace function public.register_push_subscription(
  p_endpoint   text,
  p_kind       text default 'fcm',
  p_p256dh     text default null,
  p_auth       text default null,
  p_user_agent text default null,
  p_app_target text default 'social'
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
  v_target text := lower(coalesce(nullif(trim(p_app_target), ''), 'social'));
begin
  if v_uid is null then
    raise exception 'Cihaz kaydı için oturum gerekli';
  end if;

  if coalesce(trim(p_endpoint), '') = '' then
    raise exception 'Cihaz adresi boş olamaz';
  end if;

  if v_target not in ('social', 'pro') then
    raise exception 'Geçersiz hedef uygulama: %', p_app_target;
  end if;

  insert into public.push_subscriptions
    (profile_id, endpoint, kind, p256dh, auth, user_agent, app_target)
  values
    (v_uid, p_endpoint, coalesce(nullif(trim(p_kind), ''), 'fcm'),
     p_p256dh, p_auth, p_user_agent, v_target)
  on conflict (endpoint) do update
    set profile_id = v_uid,
        kind       = excluded.kind,
        p256dh     = excluded.p256dh,
        auth       = excluded.auth,
        app_target = excluded.app_target,
        user_agent = coalesce(excluded.user_agent, push_subscriptions.user_agent);
end;
$fn$;

revoke all on function
  public.register_push_subscription(text, text, text, text, text, text)
  from public, anon;
grant execute on function
  public.register_push_subscription(text, text, text, text, text, text)
  to authenticated;

-- 8) push_subscription_state checking target ownership
drop function if exists public.push_subscription_state(text);
drop function if exists public.push_subscription_state(text, text);

create or replace function public.push_subscription_state(
  p_endpoint text,
  p_app_target text default 'social'
)
returns text
language sql
stable
security definer
set search_path = public
as $fn$
  select case
    when auth.uid() is null then 'no_session'
    when not exists (
      select 1 from public.push_subscriptions
      where endpoint = p_endpoint
        and app_target = lower(coalesce(nullif(trim(p_app_target), ''), 'social'))
    ) then 'missing'
    when exists (
      select 1 from public.push_subscriptions
      where endpoint = p_endpoint
        and app_target = lower(coalesce(nullif(trim(p_app_target), ''), 'social'))
        and profile_id = auth.uid()
    ) then 'mine'
    else 'other_account'
  end;
$fn$;

revoke all on function public.push_subscription_state(text, text) from public, anon;
grant execute on function public.push_subscription_state(text, text) to authenticated;
