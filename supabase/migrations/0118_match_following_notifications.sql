set local lock_timeout = '15s';

create table if not exists public.match_followers (
  match_id uuid not null references public.org_matches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  notify_kickoff boolean not null default true,
  notify_score boolean not null default true,
  notify_final boolean not null default true,
  muted boolean not null default false,
  created_at timestamptz not null default now(),
  primary key(match_id,profile_id)
);
create index if not exists match_followers_profile on public.match_followers(profile_id,match_id);
alter table public.match_followers enable row level security;
revoke all on public.match_followers from public,anon,authenticated;
grant select,insert,update,delete on public.match_followers to authenticated;

-- Delivery idempotency survives the user deleting a notification. Private
-- bookkeeping, never a client subscription, and no athlete/name snapshot.
create table if not exists public.match_notification_deliveries (
  match_id uuid not null references public.org_matches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  source_key text not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(match_id,profile_id,source_key)
);
alter table public.match_notification_deliveries enable row level security;
revoke all on public.match_notification_deliveries from public,anon,authenticated;

create or replace function public._match_follow_public(p_match uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.org_matches m join public.organizations o on o.id=m.org_id
    where m.id=p_match and o.official and o.is_public and m.status in ('scheduled','played'))
$$;
create or replace function public._match_follow_can_write(p_match uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select auth.uid() is not null and public._match_follow_public(p_match)
    and public._swan_feature_for_profile('live_match_notifications',auth.uid())
    and public._swan_feature_for_profile('live_match_hub',auth.uid())
$$;
revoke all on function public._match_follow_public(uuid),public._match_follow_can_write(uuid) from public,anon,authenticated;
-- Boolean policy helper reveals no private match existence or other user's state.
grant execute on function public._match_follow_can_write(uuid) to authenticated;
drop policy if exists match_follow_read on public.match_followers;
create policy match_follow_read on public.match_followers for select to authenticated using(profile_id=auth.uid());
drop policy if exists match_follow_insert on public.match_followers;
create policy match_follow_insert on public.match_followers for insert to authenticated with check(profile_id=auth.uid() and public._match_follow_can_write(match_id));
drop policy if exists match_follow_update on public.match_followers;
create policy match_follow_update on public.match_followers for update to authenticated using(profile_id=auth.uid()) with check(profile_id=auth.uid() and public._match_follow_can_write(match_id));
drop policy if exists match_follow_delete on public.match_followers;
create policy match_follow_delete on public.match_followers for delete to authenticated using(profile_id=auth.uid());

create or replace function public._match_follow_state(p_match uuid,p_profile uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare r public.match_followers; club_follow boolean; enabled boolean; followed boolean;
begin
  if p_profile is null or not public._match_follow_public(p_match) then return null;end if;
  select * into r from public.match_followers where match_id=p_match and profile_id=p_profile;
  select exists(select 1 from public.org_matches m join public.org_participants p
    on p.org_id=m.org_id and p.id in(m.home_id,m.away_id)
    join public.follows f on f.target_type='club' and f.target_id=p.club_id and f.follower_id=p_profile
    where m.id=p_match) into club_follow;
  enabled:=public._swan_feature_for_profile('live_match_notifications',p_profile)
    and public._swan_feature_for_profile('live_match_hub',p_profile);
  followed:=enabled and not coalesce(r.muted,false) and (r.match_id is not null or club_follow)
    and coalesce(r.notify_kickoff or r.notify_score or r.notify_final,true);
  return jsonb_build_object('match_id',p_match,'is_followed',followed,'muted',coalesce(r.muted,false),
    'source',case when r.muted then 'muted' when r.match_id is not null then 'match' when club_follow then 'club' else 'none' end,
    'notify_kickoff',followed and coalesce(r.notify_kickoff,true),
    'notify_score',followed and coalesce(r.notify_score,true),'notify_final',followed and coalesce(r.notify_final,true));
end $$;
revoke all on function public._match_follow_state(uuid,uuid) from public,anon,authenticated;

create or replace function public.get_match_follow_status(p_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501';end if;
  return public._match_follow_state(p_match_id,auth.uid());
end $$;

-- The UI uses explicit desired state so a timeout/retry cannot toggle twice.
create or replace function public.set_match_follow(p_match_id uuid,p_follow boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null or p_follow is null then raise exception 'Giriş ve takip tercihi gerekli' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended('match_follow:'||auth.uid()::text||':'||p_match_id::text,0));
  if p_follow and not public._match_follow_can_write(p_match_id) then raise exception 'Maç/bildirim özelliği kullanıma açık değil' using errcode='42501';end if;
  if not p_follow and not exists(select 1 from public.org_matches where id=p_match_id) then return false;end if;
  -- Off is allowed after publication/feature revocation; it does not expose a
  -- private match payload. Keep a mute override for inherited club followers.
  if not p_follow and not public._match_follow_public(p_match_id)
    and not exists(select 1 from public.match_followers where match_id=p_match_id and profile_id=auth.uid()) then return false;end if;
  insert into public.match_followers(match_id,profile_id,notify_kickoff,notify_score,notify_final,muted)
    values(p_match_id,auth.uid(),p_follow,p_follow,p_follow,not p_follow)
  on conflict(match_id,profile_id) do update set notify_kickoff=excluded.notify_kickoff,
    notify_score=excluded.notify_score,notify_final=excluded.notify_final,muted=excluded.muted;
  return p_follow;
end $$;
create or replace function public.toggle_match_follow(p_match_id uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare state jsonb;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501';end if;
  perform pg_advisory_xact_lock(hashtextextended('match_follow:'||auth.uid()::text||':'||p_match_id::text,0));
  state:=public._match_follow_state(p_match_id,auth.uid());
  if state is null then raise exception 'Maç kullanıma açık değil' using errcode='42501';end if;
  return public.set_match_follow(p_match_id,not (state->>'is_followed')::boolean);
end $$;
revoke all on function public.get_match_follow_status(uuid),public.set_match_follow(uuid,boolean),public.toggle_match_follow(uuid) from public,anon,authenticated;
grant execute on function public.get_match_follow_status(uuid),public.set_match_follow(uuid,boolean),public.toggle_match_follow(uuid) to authenticated;

create or replace function public._send_match_follow_notice(p_match uuid,p_source text,p_event text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare h jsonb; heading text; message text;
begin
  h:=public._public_match_header(p_match);
  if h is null then return;end if;
  if p_event not in ('final','correction') and not coalesce((h->>'is_live')::boolean,false) then return;end if;
  heading:=case p_event when 'kickoff' then 'Müsabaka başladı' when 'final' then 'Resmi maç sonucu'
    when 'correction' then 'Resmi sonuç düzeltildi' when 'undo' then 'Skor düzeltildi' when 'period_end' then 'Periyot / set tamamlandı' else 'Skor güncellendi' end;
  -- Device lock-screen text never contains any player/child/referee name or note.
  message:=coalesce(h->>'home_club_name','Ev Sahibi')||' — '||coalesce(h->>'away_club_name','Deplasman');
  if h->>'home_score' is not null and h->>'away_score' is not null then
    message:=message||' · '||(h->>'home_score')||' : '||(h->>'away_score');
    if h->>'sport_code'='tenis' then
      message:=message||' set';
      if p_event in ('score','undo') then message:=message||' · Oyun '||coalesce(h->>'period_home','0')||' : '||coalesce(h->>'period_away','0');end if;
    end if;
  end if;
  with candidates as (
    select mf.profile_id from public.match_followers mf where mf.match_id=p_match
    union
    select f.follower_id from public.org_matches m join public.org_participants p on p.org_id=m.org_id and p.id in(m.home_id,m.away_id)
      join public.follows f on f.target_type='club' and f.target_id=p.club_id where m.id=p_match
  ), eligible as (
    select c.profile_id from candidates c cross join lateral(select public._match_follow_state(p_match,c.profile_id) s) x
    where (x.s->>'is_followed')::boolean and (x.s->>case when p_event='kickoff' then 'notify_kickoff'
      when p_event in ('final','correction') then 'notify_final' else 'notify_score' end)::boolean
  ), deliveries as (
    insert into public.match_notification_deliveries(match_id,profile_id,source_key)
      select p_match,e.profile_id,p_source from eligible e on conflict do nothing returning profile_id
  )
  insert into public.notifications(profile_id,kind,title,body,entity_type,entity_id)
    select d.profile_id,'match_live',heading,message,'match',p_match from deliveries d;
end $$;
revoke all on function public._send_match_follow_notice(uuid,text,text) from public,anon,authenticated;

create or replace function public._notify_match_followers()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare undone text;
begin
  if tg_table_name='org_matches' then
    if new.status='played' and new.result_version>old.result_version then
      perform public._send_match_follow_notice(new.id,'result:'||new.result_version::text,
        case when old.status='played' then 'correction' else 'final' end);
    end if;
  elsif new.kind='clock_start' then
    if not exists(select 1 from public.match_live_events where match_id=new.match_id and kind='clock_start' and version<new.version) then
      perform public._send_match_follow_notice(new.match_id,'kickoff','kickoff');
    end if;
  elsif new.kind in ('score','period_end') then
    perform public._send_match_follow_notice(new.match_id,'event:'||new.id::text,new.kind);
  elsif new.kind='undo' then
    select kind into undone from public.match_live_events where id=new.undo_event_id and match_id=new.match_id;
    if undone in ('score','period_end') then perform public._send_match_follow_notice(new.match_id,'event:'||new.id::text,'undo');end if;
  end if;
  return new;
end $$;
revoke all on function public._notify_match_followers() from public,anon,authenticated;
drop trigger if exists trg_notify_match_followers on public.match_live_events;
create trigger trg_notify_match_followers after insert on public.match_live_events for each row execute function public._notify_match_followers();
drop trigger if exists trg_notify_match_follow_final on public.org_matches;
create trigger trg_notify_match_follow_final after update of result_version on public.org_matches for each row execute function public._notify_match_followers();

-- Reserve the new notification kind, protect old snapshots on publication or
-- feature revocation, including raw reads/unread counts and definer RPC reads.
create or replace function public._match_notice_visible(p_match uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select auth.uid() is not null and public._match_follow_public(p_match)
    and public._swan_feature_for_profile('live_match_notifications',auth.uid())
    and public._swan_feature_for_profile('live_match_hub',auth.uid())
$$;
revoke all on function public._match_notice_visible(uuid) from public,anon,authenticated;
grant execute on function public._match_notice_visible(uuid) to authenticated;
drop policy if exists live_notice_insert on public.notifications;
create policy live_notice_insert on public.notifications as restrictive for insert to authenticated with check(kind<>'match_live');
drop policy if exists live_notice_update on public.notifications;
create policy live_notice_update on public.notifications as restrictive for update to authenticated using(kind<>'match_live') with check(kind<>'match_live');
drop policy if exists live_notice_read on public.notifications;
create policy live_notice_read on public.notifications as restrictive for select to authenticated using(kind<>'match_live' or public._match_notice_visible(entity_id));
create or replace function public.my_notifications(p_category text default null,p_limit int default 60)
returns table(id uuid,kind text,category text,title text,body text,actor_id uuid,entity_type text,entity_id uuid,read_at timestamptz,created_at timestamptz)
language sql stable security definer set search_path=public,pg_temp as $$
 select n.id,n.kind,public.notification_category(n.kind),n.title,n.body,n.actor_id,n.entity_type,n.entity_id,n.read_at,n.created_at
 from public.notifications n where n.profile_id=auth.uid() and n.kind<>'message'
 and (n.kind<>'match_result' or public._guardian_result_visible(n.entity_id))
 and (n.kind<>'match_live' or public._match_notice_visible(n.entity_id))
 and (coalesce(p_category,'')='' or public.notification_category(n.kind)=p_category)
 order by n.created_at desc limit least(greatest(p_limit,1),200)
$$;
create or replace function public.mark_notifications_read(p_notification uuid default null)
returns void language sql security definer set search_path=public,pg_temp as $$
 update public.notifications n set read_at=coalesce(n.read_at,clock_timestamp()) where n.profile_id=auth.uid() and n.kind<>'message'
 and (p_notification is null or n.id=p_notification)
 and (n.kind<>'match_result' or public._guardian_result_visible(n.entity_id))
 and (n.kind<>'match_live' or public._match_notice_visible(n.entity_id))
$$;
revoke all on function public.my_notifications(text,int),public.mark_notifications_read(uuid) from public,anon,authenticated;
grant execute on function public.my_notifications(text,int),public.mark_notifications_read(uuid) to authenticated;

create or replace function public.push_route(p_kind text,p_entity text)
returns text language sql immutable as $fn$
 select case when p_kind='match_live' and not coalesce(p_entity ~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',false)
   then '/bildirimler' else case p_kind
    when 'match_live' then '/canli-mac/'||p_entity
    when 'referee_assignment' then '/hakem/gorevler'
    when 'match_result' then '/resmi-sonuc'
    when 'message' then '/mesajlar'
    when 'application' then '/basvurular'
    when 'offer' then '/bildirimler'
    when 'follow' then '/bildirimler'
    when 'fee' then '/aidatlarim'
    when 'fee_reminder' then '/aidatlarim'
    when 'payment' then '/finans'
    when 'donation' then '/bagis'
    when 'attendance' then '/attendance'
    when 'attendance_reminder' then '/attendance'
    when 'event' then '/calendar'
    when 'announcement' then '/announcements'
    when 'achievement' then '/performance-analytics'
    when 'document' then '/documents'
    when 'documents' then '/documents'
    when 'document_expiry' then '/documents'
    when 'partner_request' then '/partner-ara'
    when 'partner_request_accepted' then '/partner-ara'
    when 'turf_slot_request' then '/halisahalar'
    when 'turf_field' then '/halisahalar'
    when 'turf_manager' then '/halisahalar'
    when 'store_decision' then '/magaza-basvuru'
    when 'moderation' then '/pazaryeri'
    when 'expense_approval' then '/mali-isler'
    when 'expense_rejected' then '/mali-isler'
    when 'commitment_due' then '/mali-isler'
    when 'account_negative' then '/mali-isler'
    when 'bank_unmatched' then '/mali-isler'
    when 'period_closed' then '/mali-isler'
    when 'period_blocked' then '/mali-isler'
    when 'mention' then '/akis'
    when 'post_repost' then '/akis'
    when 'post_quote' then '/akis'
    when 'support' then '/destek'
    when 'eligibility' then '/athletes'
    when 'training_session' then '/antrenman-oturumu'
    when 'training_result' then '/antrenman-sonuc'
    when 'court_waitlist' then '/saha-islemlerim'
    when 'turf_delegation' then '/saha-islemlerim'
    else '/bildirimler'
 end end;
$fn$;

-- Keep existing category preferences, guardian-result route and error behavior.
create or replace function public.push_on_notification()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_subs jsonb;v_secret text;v_route text;
begin
  if not public.push_allowed(new.profile_id,new.kind) then return new;end if;
  if new.kind='match_live' and (not public._match_follow_public(new.entity_id)
    or not public._swan_feature_for_profile('live_match_notifications',new.profile_id)
    or not public._swan_feature_for_profile('live_match_hub',new.profile_id)) then return new;end if;
  v_secret:=public.push_secret();if v_secret is null or v_secret='' then return new;end if;
  select coalesce(jsonb_agg(jsonb_build_object('kind',s.kind,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth)),'[]'::jsonb)
    into v_subs from public.push_subscriptions s where s.profile_id=new.profile_id;
  if jsonb_array_length(v_subs)=0 then return new;end if;
  v_route:=case when new.kind='match_result' then '/resmi-sonuc?notification='||new.id::text
    when new.kind='match_live' then public.push_route(new.kind,new.entity_id::text)
    else public.push_route(new.kind,new.entity_type) end;
  perform net.http_post(url:='https://swansport.pages.dev/api/push',
    headers:=jsonb_build_object('Content-Type','application/json','x-push-secret',v_secret),
    body:=jsonb_build_object('title',new.title,'body',coalesce(new.body,''),'url',v_route,'subs',v_subs));
  return new;
exception when others then return new;
end $$;
revoke all on function public.push_on_notification() from public,anon,authenticated;

insert into public.feature_flags(key,audience,label) values('live_match_notifications','admins','Canlı Maç & Takım Bildirimleri') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,feature,route,sort_order)
select 'Maç ve kulüp canlı bildirimlerini nasıl açıp kapatabilirim?',
  'Canlı maç detayındaki Bildirimleri Aç düğmesiyle bu maçın başlangıç, skor/set ve resmi sonuç uyarılarını takip edebilirsiniz. Takip ettiğiniz kulübün yayımlanmış resmi maçları da kapsanır; maçtaki Bildirimleri Kapat tercihi kulüp takibinden gelen uyarıları da sessize alır. Maç tercihi cihaz bildirimi izni değildir: Bildirimler ekranından cihaz bildirimlerini ayrıca açın. iOS cihazda uygun APNs imzası/yetkisi ve Firebase yapılandırması gerekir; unsigned/ücretsiz kişisel imzalı IPA teslim garantisi vermez. Özel oyuncu/çocuk adı veya hakem rapor notu push yüküne yazılmaz. Skor düzeltmesi/geri alma yeni uyarı olabilir, gönderilmiş cihaz bildirimi geri çağrılamaz. Global Sosyal bildirim tercihi ve özellik yayın kademesi geçerlidir.',
  'spor','live_match_notifications','/canli-skor',118
where not exists(select 1 from public.faq_entries where feature='live_match_notifications' and route='/canli-skor');
