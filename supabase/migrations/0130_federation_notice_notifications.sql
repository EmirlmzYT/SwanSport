set local lock_timeout = '15s';

-- 0130: Federasyon Müsabaka Duyurusu (Erteleme / İptal) Bildirim Entegrasyonu
-- Yayımlanan resmi duyuru, müsabakayı veya takımları takip eden kullanıcılara
-- bildirim iletir. Cihaz kilit ekranında veya push yükünde çocuk/hakem/rapor
-- özel bilgisi bulunmaz; yalnızca kulüp isimleri ve güvenli durum bilgisi yer alır.

create or replace function public._public_match_header(p_match uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare rec record; st jsonb; protocol jsonb; live boolean; stamp timestamptz:=clock_timestamp();
  hs int; aws int; elapsed int; anchor timestamptz; final_at timestamptz;
begin
  select m.*,o.sport_code,o.city_code,o.name program_name,h.name home_name,a.name away_name,
    hc.logo_path home_logo,ac.logo_path away_logo into rec
  from public.org_matches m join public.organizations o on o.id=m.org_id
  left join public.org_participants h on h.id=m.home_id and h.org_id=o.id
  left join public.org_participants a on a.id=m.away_id and a.org_id=o.id
  left join public.clubs hc on hc.id=h.club_id left join public.clubs ac on ac.id=a.club_id
  where m.id=p_match and o.official and o.is_public and m.status in ('scheduled','played','cancelled','postponed');
  if not found then return null;end if;
  st:=public._referee_state(p_match);
  live:=rec.status='scheduled' and exists(select 1 from public.match_live_events e
    where e.match_id=p_match and e.kind in ('clock_start','score','card','substitution','period_end')
      and not exists(select 1 from public.match_live_events u where u.undo_event_id=e.id))
    and exists(select 1 from public.match_lineup_approvals l where l.match_id=p_match and l.participant_id=rec.home_id and l.is_locked)
    and exists(select 1 from public.match_lineup_approvals l where l.match_id=p_match and l.participant_id=rec.away_id and l.is_locked);
  elapsed:=coalesce((st->>'elapsed_seconds')::int,0);
  anchor:=case when live then (st->>'clock_started_at')::timestamptz else null end;
  if rec.status='played' then
    select r.protocol into protocol from public.public_program_result(p_match) r;
    if protocol is null then return null;end if;
    select r.recorded_at into final_at from public.org_result_revisions r where r.match_id=p_match and r.version=rec.result_version;
    if st->>'clock_started_at' is not null then
      elapsed:=elapsed+greatest(0,extract(epoch from coalesce(final_at,stamp)-(st->>'clock_started_at')::timestamptz)::int);
    end if;
    if protocol->>'type'='score' then hs:=(protocol->>'home')::int;aws:=(protocol->>'away')::int;
    elsif protocol->>'type'='sets' then
      select count(*) filter(where (s->>'home')::int>(s->>'away')::int),
        count(*) filter(where (s->>'away')::int>(s->>'home')::int) into hs,aws from jsonb_array_elements(protocol->'sets') s;
    end if;
  elsif live then
    if rec.sport_code='tenis' then
      select count(*) filter(where (s->>'home')::int>(s->>'away')::int),
        count(*) filter(where (s->>'away')::int>(s->>'home')::int) into hs,aws from jsonb_array_elements(st->'sets') s;
    else hs:=(st->>'home_score')::int;aws:=(st->>'away_score')::int;end if;
  end if;
  return jsonb_build_object('match_id',rec.id,'sport_code',rec.sport_code,'city_code',rec.city_code,
    'program_name',rec.program_name,'status',rec.status,'starts_at',rec.starts_at,'location',rec.location,
    'home_club_name',rec.home_name,'away_club_name',rec.away_name,
    'home_club_logo',rec.home_logo,'away_club_logo',rec.away_logo,
    'home_score',hs,'away_score',aws,'period',case when live then (st->>'period')::int else null end,
    'is_live',live,'is_today',coalesce((rec.starts_at at time zone 'Europe/Istanbul')::date=(stamp at time zone 'Europe/Istanbul')::date,false),
    'elapsed_seconds',elapsed,'clock_started_at',anchor,'server_now',stamp,
    'sets',case when rec.status='played' then coalesce(protocol->'sets','[]'::jsonb)
      when rec.sport_code='tenis' and live then st->'sets' else '[]'::jsonb end,
    'period_home',case when rec.sport_code='tenis' and live then (st->>'period_home')::int else null end,
    'period_away',case when rec.sport_code='tenis' and live then (st->>'period_away')::int else null end);
end $$;

create or replace function public._match_follow_public(p_match uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public.org_matches m join public.organizations o on o.id=m.org_id
    where m.id=p_match and o.official and o.is_public and m.status in ('scheduled','played','cancelled','postponed'))
$$;

create or replace function public._send_match_follow_notice(p_match uuid,p_source text,p_event text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare h jsonb; heading text; message text;
begin
  h:=public._public_match_header(p_match);
  if h is null then return;end if;
  if p_event not in ('final','correction','match_cancelled','match_postponed') and not coalesce((h->>'is_live')::boolean,false) then return;end if;
  heading:=case p_event
    when 'kickoff' then 'Müsabaka başladı'
    when 'final' then 'Resmi maç sonucu'
    when 'correction' then 'Resmi sonuç düzeltildi'
    when 'undo' then 'Skor düzeltildi'
    when 'period_end' then 'Periyot / set tamamlandı'
    when 'match_cancelled' then 'Müsabaka iptal edildi'
    when 'match_postponed' then 'Müsabaka ertelendi'
    else 'Skor güncellendi'
  end;
  -- Device lock-screen text never contains any player/child/referee name or note.
  message:=coalesce(h->>'home_club_name','Ev Sahibi')||' — '||coalesce(h->>'away_club_name','Deplasman');
  if p_event = 'match_cancelled' then
    message:=message||' müsabakası federasyon tarafından iptal edildi.';
  elsif p_event = 'match_postponed' then
    message:=message||' müsabakası federasyon tarafından ertelendi.';
  elsif h->>'home_score' is not null and h->>'away_score' is not null then
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
      when p_event in ('final','correction') then 'notify_final'
      when p_event in ('match_cancelled','match_postponed') then 'notify_kickoff'
      else 'notify_score' end)::boolean
  ), deliveries as (
    insert into public.match_notification_deliveries(match_id,profile_id,source_key)
      select p_match,e.profile_id,p_source from eligible e on conflict do nothing returning profile_id
  )
  insert into public.notifications(profile_id,kind,title,body,entity_type,entity_id)
    select d.profile_id,'match_live',heading,message,'match',p_match from deliveries d;
end $$;

revoke all on function public._public_match_header(uuid) from public,anon,authenticated;
grant execute on function public._public_match_header(uuid) to anon,authenticated;
revoke all on function public._match_follow_public(uuid) from public,anon,authenticated;
revoke all on function public._send_match_follow_notice(uuid,text,text) from public,anon,authenticated;

create or replace function public._notify_federation_match_notice()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public._send_match_follow_notice(new.match_id, 'notice:'||new.id::text, new.notice_type);
  return new;
end $$;
revoke all on function public._notify_federation_match_notice() from public,anon,authenticated;

drop trigger if exists trg_notify_federation_match_notice on public.federation_match_notices;
create trigger trg_notify_federation_match_notice
  after insert on public.federation_match_notices
  for each row execute function public._notify_federation_match_notice();
