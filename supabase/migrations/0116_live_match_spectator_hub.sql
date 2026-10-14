set local lock_timeout = '15s';

-- Read-only projections. Never grant source-table/journal access to spectators.
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
  where m.id=p_match and o.official and o.is_public and m.status in ('scheduled','played');
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

create or replace function public._public_match_athlete_name(p_match uuid,p_athlete uuid,p_side text)
returns text language plpgsql stable security definer set search_path=public,pg_temp as $$
declare a record;
begin
  if p_athlete is null then return null;end if;
  select at.id,at.first_name,at.last_name,at.birth_date,o.sport_code into a
    from public.org_matches m join public.organizations o on o.id=m.org_id and o.official and o.is_public
    join public.org_participants p on p.id=case p_side when 'home' then m.home_id when 'away' then m.away_id end and p.org_id=o.id
    join public.match_lineup_approvals l on l.match_id=m.id and l.participant_id=p.id and l.is_locked
    join public.athletes at on at.id=p_athlete and at.id=any(l.starter_athlete_ids||l.substitute_athlete_ids) and at.club_id=p.club_id
    where m.id=p_match;
  if not found then return 'sporcu';end if;
  if not exists(select 1 from public.athlete_sport_registrations r where r.athlete_id=p_athlete and r.sport_code=a.sport_code) then
    return 'sporcu';end if;
  if (a.birth_date is null or a.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date)
    and (not exists(select 1 from public.athlete_publicity ap join public.guardians g
      on g.id=ap.guardian_id and g.athlete_id=ap.athlete_id
      where ap.athlete_id=a.id and g.profile_id is not null and ap.allowed)
      or exists(select 1 from public.athlete_publicity ap join public.guardians g
      on g.id=ap.guardian_id and g.athlete_id=ap.athlete_id
      where ap.athlete_id=a.id and g.profile_id is not null and not ap.allowed)) then
    return 'sporcu';end if;
  return trim(a.first_name||' '||a.last_name);
end $$;

create or replace function public.public_live_matches(p_sport text default null,p_city text default null)
returns setof jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select x.header from public.org_matches m join public.organizations o on o.id=m.org_id
  cross join lateral(select public._public_match_header(m.id) header) x
  where o.official and o.is_public and (p_sport is null or o.sport_code=p_sport) and (p_city is null or o.city_code=p_city)
    and x.header is not null and (
      (x.header->>'is_live')::boolean
      or (m.status='scheduled' and (m.starts_at at time zone 'Europe/Istanbul')::date=(now() at time zone 'Europe/Istanbul')::date)
      or (m.status='played' and exists(select 1 from public.org_result_revisions r where r.match_id=m.id and r.version=m.result_version
        and r.recorded_at>=now()-interval '48 hours')))
  order by (x.header->>'is_live')::boolean desc,m.starts_at desc nulls last,m.id limit 200
$$;

create or replace function public.match_public_live_state(p_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare header jsonb; events jsonb; officials jsonb;
begin
  header:=public._public_match_header(p_match_id);
  if header is null then return null;end if;
  select coalesce(jsonb_agg(jsonb_build_object('sequence',e.version,'kind',e.kind,'side',e.side,
    'minute',e.elapsed_seconds/60,'elapsed_seconds',e.elapsed_seconds,'period',e.period,'card',e.card,
    'athlete_name',public._public_match_athlete_name(p_match_id,e.athlete_id,e.side),
    'replacement_name',public._public_match_athlete_name(p_match_id,e.replacement_id,e.side)) order by e.version),'[]'::jsonb)
    into events from public.match_live_events e where e.match_id=p_match_id
      and e.kind in ('score','card','substitution','period_end')
      and not exists(select 1 from public.match_live_events u where u.undo_event_id=e.id);
  select coalesce(jsonb_agg(jsonb_build_object('name',o.name,'duty',o.duty)),'[]'::jsonb)
    into officials from public.accepted_match_officials(p_match_id) o;
  return header||jsonb_build_object('events',events,'officials',officials);
end $$;

create or replace function public.match_public_roster(p_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare header jsonb; rows jsonb;
begin
  header:=public._public_match_header(p_match_id);
  if header is null then return null;end if;
  select coalesce(jsonb_agg(jsonb_build_object('side',case when l.participant_id=m.home_id then 'home' else 'away' end,
    'selection',case when ids.ord<=cardinality(l.starter_athlete_ids) then 'starter' else 'substitute' end,
    'name',public._public_match_athlete_name(m.id,ids.athlete_id,case when l.participant_id=m.home_id then 'home' else 'away' end),
    'jersey_number',at.jersey_number,'position',at.position) order by l.participant_id,ids.ord),'[]'::jsonb) into rows
  from public.org_matches m join public.match_lineup_approvals l on l.match_id=m.id and l.is_locked and l.participant_id in(m.home_id,m.away_id)
  join public.org_participants p on p.id=l.participant_id and p.org_id=m.org_id
  cross join lateral unnest(l.starter_athlete_ids||l.substitute_athlete_ids) with ordinality ids(athlete_id,ord)
  left join public.athletes at on at.id=ids.athlete_id and at.club_id=p.club_id
  where m.id=p_match_id;
  return jsonb_build_object('match_id',p_match_id,'players',rows);
end $$;

revoke all on function public._public_match_header(uuid),public._public_match_athlete_name(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.public_live_matches(text,text),public.match_public_live_state(uuid),public.match_public_roster(uuid) from public,anon,authenticated;
grant execute on function public.public_live_matches(text,text),public.match_public_live_state(uuid),public.match_public_roster(uuid) to anon,authenticated;

insert into public.feature_flags(key,audience,label) values('live_match_hub','admins','Canlı Maç & Skor Takip Merkezi') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,feature,route,sort_order)
select 'Canlı maçları ve skorları nereden takip edebilirim?',
  'Keşfet içindeki Canlı Skor Merkezi üzerinden kamuya yayımlanmış resmi maçları, günün fikstürünü ve son 48 saatte sonuçlanan maçları izleyebilirsiniz. Devam eden skor hakem günlüğünden gelir; kesinleşmiş skor resmi sonuç revizyonudur. Çocuk adları veli yayın iznine göre gizlenir. Hakem özel notları, sağlık bilgileri ve disiplin sevkleri gösterilmez. Canlı veriler aralıklı yenilenir; bağlantı hatasında yeniden deneyin.',
  'spor','live_match_hub','/canli-skor',116
where not exists(select 1 from public.faq_entries where feature='live_match_hub' and route='/canli-skor');
