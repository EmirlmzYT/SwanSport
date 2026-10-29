set local lock_timeout = '15s';

-- A revision protects device ownership/credentials from stale HTTP responses.
alter table public.push_subscriptions add column if not exists delivery_revision bigint not null default 1;
create or replace function public._push_registration_revision() returns trigger
language plpgsql set search_path=public,pg_temp as $$
begin
  if row(new.profile_id,new.endpoint,new.kind,new.p256dh,new.auth)
    is distinct from row(old.profile_id,old.endpoint,old.kind,old.p256dh,old.auth) then
    new.delivery_revision:=old.delivery_revision+1;
  else new.delivery_revision:=old.delivery_revision;
  end if;
  return new;
end $$;
revoke all on function public._push_registration_revision() from public,anon,authenticated;
drop trigger if exists push_registration_revision on public.push_subscriptions;
create trigger push_registration_revision before update on public.push_subscriptions
  for each row execute function public._push_registration_revision();

-- No body, device token, push secret or provider error text is retained here.
create table if not exists public.push_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null references public.notifications(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  subscription_id uuid references public.push_subscriptions(id) on delete set null,
  subscription_revision bigint not null,
  status text not null default 'pending' check(status in ('pending','in_flight','accepted','retry','failed','unknown','skipped','expired')),
  attempt_count int not null default 0 check(attempt_count between 0 and 3),
  request_id bigint,
  last_attempt_at timestamptz,
  next_attempt_at timestamptz not null default now(),
  expires_at timestamptz not null,
  last_outcome text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(notification_id,subscription_id)
);
create index if not exists push_delivery_work on public.push_delivery_attempts(status,next_attempt_at);
alter table public.push_delivery_attempts enable row level security;
revoke all on public.push_delivery_attempts from public,anon,authenticated;
grant select on public.push_delivery_attempts to authenticated;
drop policy if exists push_delivery_admin_read on public.push_delivery_attempts;
create policy push_delivery_admin_read on public.push_delivery_attempts for select to authenticated
  using (public.is_platform_admin());

create or replace function public._push_delivery_permitted(n public.notifications) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select coalesce(public.push_allowed(n.profile_id,n.kind),false) and
   (n.kind<>'message' or exists(select 1 from public.direct_messages dm
     where dm.id=n.entity_id and dm.recipient_id=n.profile_id
       and not public.is_blocked_between(dm.sender_id,dm.recipient_id))) and
   (n.kind<>'match_result' or exists(select 1 from public.guardians g
     where g.profile_id=n.profile_id and g.athlete_id=n.entity_id)) and
   (n.kind<>'match_live' or (
     public._match_follow_public(n.entity_id) and
     public._swan_feature_for_profile('live_match_notifications',n.profile_id) and
     public._swan_feature_for_profile('live_match_hub',n.profile_id) and
     coalesce((public._match_follow_state(n.entity_id,n.profile_id)->>'is_followed')::boolean,false)))
$$;
revoke all on function public._push_delivery_permitted(public.notifications) from public,anon,authenticated;

create or replace function public._dispatch_push_delivery(p_id uuid) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
declare d public.push_delivery_attempts; n public.notifications; s public.push_subscriptions;
  secret text; route text; request bigint;
begin
 select * into d from public.push_delivery_attempts where id=p_id for update skip locked;
 if not found or d.status not in ('pending','retry') or d.next_attempt_at>now() then return; end if;
 if d.expires_at<=now() then
   update public.push_delivery_attempts set status='expired',updated_at=now() where id=d.id;return;
 end if;
 select * into n from public.notifications where id=d.notification_id;
 if not found then return;end if;
 select * into s from public.push_subscriptions where id=d.subscription_id and profile_id=d.profile_id
   and delivery_revision=d.subscription_revision for share;
 if not found or not coalesce(public._push_delivery_permitted(n),false) then
   update public.push_delivery_attempts set status='skipped',last_outcome='registration_or_preference_changed',updated_at=now() where id=d.id;return;
 end if;
 secret:=public.push_secret();
 if secret is null or secret='' then
   update public.push_delivery_attempts set status='failed',last_outcome='configuration_missing',updated_at=now() where id=d.id;return;
 end if;
 route:=case when n.kind='match_result' then '/resmi-sonuc?notification='||n.id::text
   when n.kind='match_live' then public.push_route(n.kind,n.entity_id::text)
   else public.push_route(n.kind,n.entity_type) end;
 request:=net.http_post(url:='https://swansport.pages.dev/api/push',
   headers:=jsonb_build_object('Content-Type','application/json','x-push-secret',secret),
   body:=jsonb_build_object('title',n.title,'body',coalesce(n.body,''),'url',route,
     'subs',jsonb_build_array(jsonb_build_object('kind',s.kind,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth))));
 update public.push_delivery_attempts set status='in_flight',attempt_count=attempt_count+1,
   request_id=request,last_attempt_at=now(),updated_at=now(),last_outcome=null where id=d.id;
exception when others then
 -- pg_net enqueue is transactional: an enqueue error has not delivered a push.
 update public.push_delivery_attempts set status='failed',last_outcome='enqueue_failed',updated_at=now() where id=p_id;
end $$;
revoke all on function public._dispatch_push_delivery(uuid) from public,anon,authenticated;

create or replace function public.process_push_deliveries(p_limit int default 100) returns int
language plpgsql security definer set search_path=public,pg_temp as $$
declare d public.push_delivery_attempts; r record; payload jsonb; result jsonb;
  provider_status int; processed int:=0; cap int:=least(greatest(coalesce(p_limit,100),1),100);
begin
 for d in select * from public.push_delivery_attempts where status='in_flight'
   order by last_attempt_at for update skip locked limit cap loop
   select * into r from net._http_response where id=d.request_id;
   if not found then
     if d.last_attempt_at<now()-interval '2 minutes' then
       update public.push_delivery_attempts set status='unknown',last_outcome='response_missing',updated_at=now() where id=d.id;
     end if;
     continue;
   end if;
   -- Ambiguous transport failures are NEVER automatically retried.
   if r.timed_out or r.error_msg is not null or r.status_code<>200 then
     update public.push_delivery_attempts set status='unknown',last_outcome='transport_or_sender_failure',updated_at=now() where id=d.id;
     continue;
   end if;
   begin
     payload:=r.content::jsonb; result:=payload->'results'->0;
     if jsonb_typeof(payload->'results') is distinct from 'array' or jsonb_array_length(payload->'results')<>1
       or jsonb_typeof(result->'status') is distinct from 'number' then raise exception 'Invalid result';end if;
     provider_status:=(result->>'status')::int;
     if provider_status in (200,201) then
       update public.push_delivery_attempts set status='accepted',last_outcome='provider_accepted',updated_at=now() where id=d.id;
     elsif result->>'gone'='true' and provider_status in (404,410) and result->>'retryable'='false' then
       -- Legacy senders marked every FCM 404 as gone. Only the new explicit
       -- classification may remove a token during a staggered deployment.
       -- Protect account transfers and registrations with changed credentials.
       delete from public.push_subscriptions where id=d.subscription_id and profile_id=d.profile_id
         and delivery_revision=d.subscription_revision;
       update public.push_delivery_attempts set status='failed',last_outcome='token_unregistered',updated_at=now() where id=d.id;
     elsif result->>'retryable'='true' and provider_status in (429,500,503) and d.attempt_count<3 then
       update public.push_delivery_attempts set status='retry',last_outcome='provider_rejected_temporary',
         next_attempt_at=now()+make_interval(secs=>60*d.attempt_count),updated_at=now() where id=d.id;
     elsif provider_status=0 then
       update public.push_delivery_attempts set status='unknown',last_outcome='sender_result_uncertain',updated_at=now() where id=d.id;
     else
       update public.push_delivery_attempts set status='failed',last_outcome='provider_rejected',updated_at=now() where id=d.id;
     end if;
   exception when others then
     update public.push_delivery_attempts set status='unknown',last_outcome='invalid_response',updated_at=now() where id=d.id;
   end;
   processed:=processed+1;
 end loop;
 for d in select * from public.push_delivery_attempts where status in ('pending','retry') and next_attempt_at<=now()
   order by next_attempt_at for update skip locked limit cap loop
   perform public._dispatch_push_delivery(d.id);processed:=processed+1;
 end loop;
 delete from public.push_delivery_attempts where status not in ('pending','retry','in_flight') and updated_at<now()-interval '30 days';
 return processed;
end $$;
revoke all on function public.process_push_deliveries(int) from public,anon,authenticated;
grant execute on function public.process_push_deliveries(int) to service_role;

create or replace function public.push_on_notification() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.push_subscriptions; delivery uuid;
begin
 if not coalesce(public._push_delivery_permitted(new),false) then return new;end if;
 for s in select * from public.push_subscriptions where profile_id=new.profile_id loop
   insert into public.push_delivery_attempts(notification_id,profile_id,subscription_id,subscription_revision,expires_at)
   values(new.id,new.profile_id,s.id,s.delivery_revision,
     now()+case when new.kind='match_live' then interval '60 seconds' else interval '1 day' end)
   on conflict(notification_id,subscription_id) do nothing returning id into delivery;
   if delivery is not null then perform public._dispatch_push_delivery(delivery);end if;
 end loop;
 return new;
end $$;
revoke all on function public.push_on_notification() from public,anon,authenticated;
drop trigger if exists trg_push_on_notification on public.notifications;
create trigger trg_push_on_notification after insert on public.notifications
  for each row execute function public.push_on_notification();

do $$begin
 if exists(select 1 from pg_namespace where nspname='cron') then
   perform cron.schedule('swansport_push_delivery','* * * * *','select public.process_push_deliveries(100);');
 end if;
end $$;
