set local lock_timeout = '15s';

-- Private, append-only event journal. No athlete/name subscriptions or public feed.
create table if not exists public.match_live_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.org_matches(id) on delete restrict,
  version int not null check(version > 0),
  operation_id uuid not null,
  actor_id uuid references public.profiles(id) on delete set null,
  kind text not null check(kind in ('score','card','substitution','period_end','clock_start','clock_pause','undo')),
  side text check(side in ('home','away')),
  athlete_id uuid,
  replacement_id uuid,
  card text check(card in ('yellow','red','two_minutes','technical')),
  elapsed_seconds int not null default 0,
  period int not null default 1,
  undo_event_id uuid references public.match_live_events(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique(match_id,version), unique(match_id,operation_id)
);
create table if not exists public.referee_match_reports (
  revision_id uuid primary key references public.org_result_revisions(id) deferrable initially deferred,
  match_id uuid not null unique references public.org_matches(id) on delete restrict,
  operation_id uuid not null unique,
  actor_id uuid references public.profiles(id) on delete set null,
  home_approval_id uuid not null references public.match_lineup_approvals(id) on delete restrict,
  away_approval_id uuid not null references public.match_lineup_approvals(id) on delete restrict,
  notes text not null check(length(notes) between 1 and 500),
  timeline_version int not null,
  signed_at timestamptz not null default clock_timestamp()
);
-- Transaction-local capability is a private ROW, not a caller-forgeable GUC.
create table if not exists public._referee_write_context (
  transaction_id bigint primary key, actor_id uuid not null,
  match_id uuid not null, revision_id uuid not null
);
alter table public.match_live_events enable row level security;
alter table public.referee_match_reports enable row level security;
alter table public._referee_write_context enable row level security;
revoke all on public.match_live_events, public.referee_match_reports, public._referee_write_context from public,anon,authenticated;

create or replace function public._referee_controller(p_match uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select auth.uid() is not null and exists(
    select 1 from public.match_officials mo
    join public.referee_profiles rp on rp.profile_id=mo.profile_id and rp.is_active
    join public.org_matches m on m.id=mo.match_id
    join public.organizations o on o.id=m.org_id and o.official and o.sport_code=rp.sport_code
    where mo.match_id=p_match and mo.profile_id=auth.uid() and mo.status='accepted'
      and mo.duty in ('head_referee','table_official'))
$$;
create or replace function public._referee_require(p_match uuid,p_locked boolean default false)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare m public.org_matches;
begin
  if not public._referee_controller(p_match) then raise exception 'Kabul edilmiş aktif başhakem/masa görevi gerekli' using errcode='42501'; end if;
  perform 1 from public.match_officials mo join public.referee_profiles rp on rp.profile_id=mo.profile_id
    where mo.match_id=p_match and mo.profile_id=auth.uid() and mo.status='accepted'
      and mo.duty in ('head_referee','table_official') and rp.is_active for share of mo,rp;
  if not found or not public._referee_controller(p_match) then raise exception 'Maç görevi değişti' using errcode='42501';end if;
  select * into m from public.org_matches where id=p_match;
  if p_locked and (m.home_id is null or m.away_id is null or
    not exists(select 1 from public.match_lineup_approvals a where a.match_id=m.id and a.participant_id=m.home_id and a.is_locked) or
    not exists(select 1 from public.match_lineup_approvals a where a.match_id=m.id and a.participant_id=m.away_id and a.is_locked)) then
    raise exception 'İki tarafın kilitli esamesi gerekli' using errcode='55000';
  end if;
end $$;

create or replace function public.referee_lineup_candidates(p_match_id uuid)
returns table(athlete_id uuid,side text,name text,jersey_number int,license_number text,
  license_expires_on date,eligibility_status text,eligible boolean,selection text)
language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public._referee_require(p_match_id);
  return query
  select a.id,case when p.id=m.home_id then 'home'::text else 'away'::text end,
    case when (a.birth_date is null or a.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date)
      and (not exists(select 1 from public.athlete_publicity ap join public.guardians g on g.id=ap.guardian_id where ap.athlete_id=a.id and ap.allowed and g.profile_id is not null)
        or exists(select 1 from public.athlete_publicity ap join public.guardians g on g.id=ap.guardian_id where ap.athlete_id=a.id and not ap.allowed and g.profile_id is not null))
      then null else trim(a.first_name||' '||a.last_name) end,
    a.jersey_number,r.license_number,r.expires_on,
    case when exists(select 1 from public.eligibility_gate(a.id) g where g.blocked and g.reason_code<>'license_expired') then 'medical'
      when n.status='injured_medical' then 'medical' when n.status='suspended' then 'suspended'
      when n.status in ('rested','injured_admin') then 'rested'
      when r.athlete_id is null or r.club_id is distinct from p.club_id or r.expires_on<o.ends_on or r.expires_on<(now() at time zone 'Europe/Istanbul')::date then 'license'
      else 'eligible' end,
    not exists(select 1 from public.eligibility_gate(a.id) g where g.blocked and g.reason_code<>'license_expired')
      and coalesce(n.status,'eligible')='eligible' and r.athlete_id is not null and r.club_id=p.club_id
      and r.expires_on>=o.ends_on and r.expires_on>=(now() at time zone 'Europe/Istanbul')::date,
    case when a.id=any(la.starter_athlete_ids) then 'starter' when a.id=any(la.substitute_athlete_ids) then 'substitute' else 'unselected' end
  from public.org_matches m join public.organizations o on o.id=m.org_id and o.official
  join public.org_participants p on p.id in(m.home_id,m.away_id)
  left join public.match_lineup_approvals la on la.match_id=m.id and la.participant_id=p.id
  join lateral(select rr.athlete_ids from public.org_roster_revisions rr where rr.participant_id=p.id
    and (la.id is null or rr.id=la.roster_revision_id) order by rr.version desc limit 1) rr on true
  join public.athletes a on a.id=any(case when la.id is null then rr.athlete_ids else la.starter_athlete_ids||la.substitute_athlete_ids end) and a.club_id=p.club_id
  left join public.athlete_sport_registrations r on r.athlete_id=a.id and r.sport_code=o.sport_code
  left join public.org_match_lineup_notes n on n.match_id=m.id and n.athlete_id=a.id
  where m.id=p_match_id order by 2,a.jersey_number,a.id;
end $$;

-- Rebuild from the journal, never from a client-supplied score. Undo is append-only.
create or replace function public._referee_state(p_match uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare m public.org_matches;e public.match_live_events;h int:=0;a int:=0;period int:=1;
  hh int:=0;aa int:=0;sets jsonb:='[]';active_home uuid[];active_away uuid[];bench_home uuid[];bench_away uuid[];
  anchor timestamptz;seconds int:=0;events jsonb:='[]';v int;s text;
begin
  select * into m from public.org_matches where id=p_match;
  select o.sport_code into s from public.organizations o where o.id=m.org_id;
  select l.starter_athlete_ids,l.substitute_athlete_ids into active_home,bench_home from public.match_lineup_approvals l where l.match_id=m.id and l.participant_id=m.home_id;
  select l.starter_athlete_ids,l.substitute_athlete_ids into active_away,bench_away from public.match_lineup_approvals l where l.match_id=m.id and l.participant_id=m.away_id;
  for e in select x.* from public.match_live_events x where x.match_id=p_match and x.kind<>'undo'
    and not exists(select 1 from public.match_live_events u where u.undo_event_id=x.id) order by x.version loop
    if e.kind='score' then
      if e.side='home' then h:=h+1;hh:=hh+1;else a:=a+1;aa:=aa+1;end if;
    elsif e.kind='substitution' then
      if e.side='home' then active_home:=array_remove(active_home,e.athlete_id)||e.replacement_id;bench_home:=array_remove(bench_home,e.replacement_id);
        if s<>'futbol' then bench_home:=bench_home||e.athlete_id;end if;
      else active_away:=array_remove(active_away,e.athlete_id)||e.replacement_id;bench_away:=array_remove(bench_away,e.replacement_id);
        if s<>'futbol' then bench_away:=bench_away||e.athlete_id;end if;end if;
    elsif e.kind='card' and e.card='red' then
      if e.side='home' then active_home:=array_remove(active_home,e.athlete_id);else active_away:=array_remove(active_away,e.athlete_id);end if;
    elsif e.kind='period_end' then
      sets:=sets||jsonb_build_array(jsonb_build_object('home',hh,'away',aa));hh:=0;aa:=0;period:=period+1;
      if anchor is not null then seconds:=seconds+greatest(0,extract(epoch from e.created_at-anchor)::int);anchor:=null;end if;
    elsif e.kind='clock_start' then anchor:=e.created_at;
    elsif e.kind='clock_pause' and anchor is not null then seconds:=seconds+greatest(0,extract(epoch from e.created_at-anchor)::int);anchor:=null;
    end if;
  end loop;
  select coalesce(max(x.version),0),coalesce(jsonb_agg(jsonb_build_object('id',x.id,'version',x.version,'kind',x.kind,'side',x.side,
    'athlete_id',x.athlete_id,'replacement_id',x.replacement_id,'card',x.card,'created_at',x.created_at,'elapsed_seconds',x.elapsed_seconds,'period',x.period,
    'undone',exists(select 1 from public.match_live_events u where u.undo_event_id=x.id)) order by x.version),'[]')
    into v,events from public.match_live_events x where x.match_id=p_match;
  return jsonb_build_object('match_id',m.id,'sport_code',s,'match_status',m.status,'version',v,
    'home_score',h,'away_score',a,'period',period,'period_home',hh,'period_away',aa,'sets',sets,
    'active_home',coalesce(active_home,'{}'),'active_away',coalesce(active_away,'{}'),
    'bench_home',coalesce(bench_home,'{}'),'bench_away',coalesce(bench_away,'{}'),
    'elapsed_seconds',seconds,'clock_started_at',anchor,'events',events,
    'report_revision_id',(select r.revision_id from public.referee_match_reports r where r.match_id=p_match),
    'report_notes',(select r.notes from public.referee_match_reports r where r.match_id=p_match));
end $$;
create or replace function public.referee_match_state(p_match_id uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin perform public._referee_require(p_match_id,true);return public._referee_state(p_match_id);end $$;

create or replace function public.referee_append_match_event(p_match_id uuid,p_operation_id uuid,p_expected_version int,
  p_kind text,p_side text default null,p_athlete_id uuid default null,p_replacement_id uuid default null,p_card text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare m public.org_matches;st jsonb;prior public.match_live_events;target uuid;v int;ev uuid;
begin
  perform 1 from public.profiles where id=auth.uid() for key share;
  if not found then raise exception 'Giriş gerekli' using errcode='42501';end if;
  perform pg_advisory_xact_lock(110,hashtext(p_match_id::text));
  select * into m from public.org_matches where id=p_match_id for update;
  perform public._referee_require(p_match_id,true);
  select * into prior from public.match_live_events where match_id=p_match_id and operation_id=p_operation_id;
  if prior.id is not null then
    if prior.actor_id is distinct from auth.uid() or (prior.kind,prior.side,prior.athlete_id,prior.replacement_id,prior.card)
      is distinct from (p_kind,p_side,p_athlete_id,p_replacement_id,p_card) then raise exception 'İşlem kimliği farklı içerikle tekrar kullanıldı' using errcode='22023';end if;
    return public._referee_state(p_match_id);
  end if;
  if m.status<>'scheduled' or m.result_version<>0 then raise exception 'Maç kapalı' using errcode='55000';end if;
  st:=public._referee_state(p_match_id);v:=(st->>'version')::int;
  if p_expected_version is distinct from v then raise exception 'Olay sürümü değişti; güncel kaydı yükle' using errcode='40001';end if;
  if p_operation_id is null or p_kind is null or p_kind not in ('score','card','substitution','period_end','clock_start','clock_pause','undo') then raise exception 'Olay geçersiz' using errcode='22023';end if;
  if st->>'sport_code' not in ('futbol','basketbol','tenis') then raise exception 'Bu branşın canlı sonuç protokolü henüz desteklenmiyor' using errcode='22023';end if;
  if p_kind in ('score','card','substitution') then
    if p_side is null or p_side not in ('home','away') then raise exception 'Taraf gerekli' using errcode='22023';end if;
    if p_athlete_id is not null and not (st->('active_'||p_side)) @> jsonb_build_array(p_athlete_id::text) then raise exception 'Sporcu sahada değil' using errcode='22023';end if;
  elsif p_side is not null or p_athlete_id is not null then raise exception 'Olay alanları geçersiz' using errcode='22023';end if;
  if p_kind='card' then
    if p_athlete_id is null or p_card is null or p_card not in ('yellow','red','two_minutes','technical') then raise exception 'Kart/sporcu gerekli' using errcode='22023';end if;
  elsif p_card is not null then raise exception 'Kart yalnız kart olayında kullanılabilir' using errcode='22023';end if;
  if p_kind='substitution' then
    if p_athlete_id is null or p_replacement_id is null or p_athlete_id=p_replacement_id
      or not (st->('bench_'||p_side)) @> jsonb_build_array(p_replacement_id::text)
      or exists(select 1 from public.eligibility_gate(p_replacement_id) g where g.blocked and g.reason_code<>'license_expired')
      or exists(select 1 from public.org_match_lineup_notes n where n.match_id=m.id and n.athlete_id=p_replacement_id and n.status<>'eligible') then raise exception 'Değişiklik uygun değil' using errcode='22023';end if;
  elsif p_replacement_id is not null then raise exception 'Giren sporcu yalnız değişiklikte kullanılabilir' using errcode='22023';end if;
  if p_kind='clock_start' and st->>'clock_started_at' is not null then raise exception 'Süre zaten çalışıyor';end if;
  if p_kind='clock_pause' and st->>'clock_started_at' is null then raise exception 'Süre duruyor';end if;
  if p_kind='period_end' and st->>'sport_code'='tenis' and not (
    greatest((st->>'period_home')::int,(st->>'period_away')::int) in(6,7) and
    ((greatest((st->>'period_home')::int,(st->>'period_away')::int)=6 and least((st->>'period_home')::int,(st->>'period_away')::int)<=4)
      or (greatest((st->>'period_home')::int,(st->>'period_away')::int)=7 and least((st->>'period_home')::int,(st->>'period_away')::int) in(5,6)))) then raise exception 'Teniste tamamlanmış set gerekli';end if;
  if p_kind='undo' then
    select x.id into target from public.match_live_events x where x.match_id=m.id and x.kind<>'undo'
      and not exists(select 1 from public.match_live_events u where u.undo_event_id=x.id) order by x.version desc limit 1;
    if target is null then raise exception 'Geri alınacak olay yok';end if;
  end if;
  insert into public.match_live_events(match_id,version,operation_id,actor_id,kind,side,athlete_id,replacement_id,card,undo_event_id,elapsed_seconds,period)
    values(m.id,v+1,p_operation_id,auth.uid(),p_kind,p_side,p_athlete_id,p_replacement_id,p_card,target,
      (st->>'elapsed_seconds')::int+case when st->>'clock_started_at' is null then 0 else greatest(0,extract(epoch from clock_timestamp()-(st->>'clock_started_at')::timestamptz)::int) end,(st->>'period')::int) returning id into ev;
  insert into public.federation_audit(actor_id,action,entity_id,detail) values(auth.uid(),'referee_live_event',m.id,jsonb_build_object('event_id',ev,'version',v+1,'kind',p_kind));
  return public._referee_state(m.id);
end $$;

create or replace function public._referee_context(p_match uuid,p_revision uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select exists(select 1 from public._referee_write_context c where c.transaction_id=txid_current()
    and c.actor_id=auth.uid() and c.match_id=p_match and c.revision_id=p_revision)
$$;
create or replace function public._referee_revision_athletes(p_revision uuid,p_roster uuid,p_fallback uuid[])
returns uuid[] language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select case when rr.participant_id=h.participant_id then h.starter_athlete_ids||h.substitute_athlete_ids
    when rr.participant_id=a.participant_id then a.starter_athlete_ids||a.substitute_athlete_ids else '{}'::uuid[] end
    from public.referee_match_reports r join public.match_lineup_approvals h on h.id=r.home_approval_id
    join public.match_lineup_approvals a on a.id=r.away_approval_id
    join public.org_result_revisions rv on rv.match_id=r.match_id and rv.id=p_revision
    join public.org_roster_revisions rr on rr.id=p_roster),p_fallback)
$$;
-- Surgical adaptation of existing trusted helpers. Their normal authorization,
-- validation and signatures stay intact. Fail loudly if upstream bodies drift.
do $$ declare d text;n text;needle text;replacement text;begin
  d:=pg_get_functiondef('public._federation_guard()'::regprocedure);
  needle:='v_appointment:=public._federation_require(v_sport,v_city,v_duty);';
  replacement:='if not (v_duty=''result_publisher'' and case when tg_table_name=''org_matches'' then public._referee_context((to_jsonb(new)->>''id'')::uuid,(select rv.id from public.org_result_revisions rv where rv.match_id=(to_jsonb(new)->>''id'')::uuid and rv.version=(to_jsonb(new)->>''result_version'')::int)) when tg_table_name=''athlete_achievements'' then public._referee_context((to_jsonb(new)->>''official_match_id'')::uuid,(to_jsonb(new)->>''source_id'')::uuid) else false end) then v_appointment:=public._federation_require(v_sport,v_city,v_duty); end if;';
  if position(replacement in d)=0 then
    if position(needle in d)=0 then raise exception 'Federation guard contract changed';end if;
    d:=replace(d,needle,replacement);
  end if;
  d:=replace(d,'new.athlete_id=any(r.athlete_ids)','new.athlete_id=any(public._referee_revision_athletes(rv.id,r.id,r.athlete_ids))');execute d;
  d:=pg_get_functiondef('public._federation_result_cv(uuid)'::regprocedure);
  needle:='perform public._federation_require(o.sport_code,o.city_code,''result_publisher'');';
  replacement:='if not public._referee_context(m.id,p_revision) then perform public._federation_require(o.sport_code,o.city_code,''result_publisher''); end if;';
  if position(replacement in d)=0 then
    if position(needle in d)=0 then raise exception 'Result CV contract changed';end if;
    d:=replace(d,needle,replacement);
  end if;
  d:=replace(d,'unnest(r.athlete_ids)','unnest(public._referee_revision_athletes(rv.id,r.id,r.athlete_ids))');
  d:=replace(d,'k=any(r.athlete_ids)','k=any(public._referee_revision_athletes(rv.id,r.id,r.athlete_ids))');execute d;
  foreach n in array array['_notify_guardian_official_result()','guardian_calendar_results(timestamp with time zone,timestamp with time zone)'] loop
    d:=pg_get_functiondef(('public.'||n)::regprocedure);
    d:=replace(d,'a.id=any(rr.athlete_ids)','a.id=any(public._referee_revision_athletes(rv.id,rr.id,rr.athlete_ids))');execute d;
  end loop;
  d:=pg_get_functiondef('public._guardian_result_summary(uuid,uuid)'::regprocedure);
  d:=replace(d,'p_child=any(rr.athlete_ids)','p_child=any(public._referee_revision_athletes(r.id,rr.id,rr.athlete_ids))');execute d;
end $$;

create or replace function public.referee_submit_match_report(p_match_id uuid,p_operation_id uuid,p_expected_version int,p_notes text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare m public.org_matches;st jsonb;h public.match_lineup_approvals;a public.match_lineup_approvals;r public.referee_match_reports;v uuid;protocol jsonb;hs int;aws int;
begin
  perform 1 from public.profiles where id=auth.uid() for key share;
  if not found then raise exception 'Giriş gerekli' using errcode='42501';end if;
  perform pg_advisory_xact_lock(110,hashtext(p_match_id::text));
  select * into m from public.org_matches where id=p_match_id for update;
  perform public._referee_require(p_match_id,true);
  select * into r from public.referee_match_reports where match_id=m.id;
  if r.revision_id is not null then
    if r.operation_id=p_operation_id and r.actor_id=auth.uid() and r.notes=p_notes and r.timeline_version=p_expected_version then return r.revision_id;end if;
    raise exception 'Rapor zaten tescilli; düzeltme federasyon revizyonuyla yapılır' using errcode='55000';
  end if;
  if m.status<>'scheduled' or m.result_version<>0 then raise exception 'Maç kapalı';end if;
  st:=public._referee_state(m.id);
  if p_expected_version is distinct from (st->>'version')::int then raise exception 'Olay sürümü değişti' using errcode='40001';end if;
  if p_operation_id is null or p_notes is null or length(trim(p_notes)) not between 1 and 500 then raise exception 'Rapor notu gerekli';end if;
  if st->>'clock_started_at' is not null then raise exception 'Önce süreyi durdur';end if;
  if st->>'sport_code'='tenis' then
    if (st->>'period_home')::int<>0 or (st->>'period_away')::int<>0 or jsonb_array_length(st->'sets') not between 2 and 5 then raise exception 'Tamamlanmış tenis setleri gerekli';end if;
    select count(*) filter(where (e->>'home')::int>(e->>'away')::int),count(*) filter(where (e->>'away')::int>(e->>'home')::int) into hs,aws from jsonb_array_elements(st->'sets') e;
    if greatest(hs,aws) not in(2,3) or hs=aws then raise exception 'Tenis galibi belirlenmeli';end if;
    protocol:=jsonb_build_object('type','sets','sets',st->'sets');
  elsif st->>'sport_code' in ('futbol','basketbol') then
    protocol:=jsonb_build_object('type','score','home',(st->>'home_score')::int,'away',(st->>'away_score')::int);
  else raise exception 'Bu branşın rapor protokolü desteklenmiyor';end if;
  if not public._valid_official_protocol(protocol) then raise exception 'Sonuç protokolü geçersiz';end if;
  select * into h from public.match_lineup_approvals where match_id=m.id and participant_id=m.home_id;
  select * into a from public.match_lineup_approvals where match_id=m.id and participant_id=m.away_id;
  v:=gen_random_uuid();
  insert into public.referee_match_reports(revision_id,match_id,operation_id,actor_id,home_approval_id,away_approval_id,notes,timeline_version)
    values(v,m.id,p_operation_id,auth.uid(),h.id,a.id,p_notes,p_expected_version);
  insert into public._referee_write_context values(txid_current(),auth.uid(),m.id,v);
  insert into public.org_result_revisions(id,match_id,version,protocol,reason,actor_id,home_roster_revision_id,away_roster_revision_id)
    values(v,m.id,1,protocol,'Hakem imzalı maç raporu',auth.uid(),h.roster_revision_id,a.roster_revision_id);
  update public.org_matches set result_protocol=protocol,result_version=1,status='played',
    home_score=case when protocol->>'type'='score' then (protocol->>'home')::int end,
    away_score=case when protocol->>'type'='score' then (protocol->>'away')::int end where id=m.id;
  perform public._federation_result_cv(v);
  insert into public.federation_audit(actor_id,action,entity_id,detail) values(auth.uid(),'referee_report_signed',m.id,jsonb_build_object('revision_id',v,'timeline_version',p_expected_version));
  delete from public._referee_write_context where transaction_id=txid_current();
  return v;
end $$;

-- Extend the existing own-assignment projection without leaving an overload.
drop function if exists public.my_referee_matches(text);
create function public.my_referee_matches(p_status text default null)
returns table(official_id uuid,match_id uuid,duty text,status text,assigned_at timestamptz,
  starts_at timestamptz,location text,sport_code text,home_club_name text,away_club_name text,
  decline_reason text,match_status text,city_code text)
language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501';end if;
  if p_status is not null and p_status not in ('assigned','accepted','declined','replaced') then raise exception 'Atama filtresi geçersiz';end if;
  return query select mo.id,m.id,mo.duty,mo.status,mo.assigned_at,m.starts_at,m.location,o.sport_code,
    coalesce(hc.legal_name,hc.name),coalesce(ac.legal_name,ac.name),mo.decline_reason,m.status,o.city_code
  from public.match_officials mo join public.org_matches m on m.id=mo.match_id
  join public.organizations o on o.id=m.org_id and o.official
  left join public.org_participants hp on hp.id=m.home_id left join public.clubs hc on hc.id=hp.club_id
  left join public.org_participants ap on ap.id=m.away_id left join public.clubs ac on ac.id=ap.club_id
  where mo.profile_id=auth.uid() and (p_status is null or mo.status=p_status)
  order by m.starts_at nulls last,mo.id;
end $$;
revoke all on function public.my_referee_matches(text) from public,anon,authenticated;
grant execute on function public.my_referee_matches(text) to authenticated;

create or replace function public._notify_referee_assignment()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if new.status='assigned' and (tg_op='INSERT' or (to_jsonb(old)->>'status') is distinct from 'assigned') then
    insert into public.notifications(profile_id,kind,title,body,entity_type,entity_id)
      values(new.profile_id,'referee_assignment','Yeni müsabaka görevi','Görevi Hakem Kokpitinden inceleyip yanıtlayabilirsin.','match',new.match_id);
  end if;
  return new;
end $$;
revoke all on function public._notify_referee_assignment() from public,anon,authenticated;
drop trigger if exists notify_referee_assignment on public.match_officials;
create trigger notify_referee_assignment after insert or update of status on public.match_officials for each row execute function public._notify_referee_assignment();

create or replace function public._referee_journal_immutable()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if tg_op='UPDATE' and pg_trigger_depth()>1 and new.actor_id is null and old.actor_id is not null
    and (to_jsonb(new)-'actor_id')=(to_jsonb(old)-'actor_id') then return new;end if;
  raise exception 'Hakem olay/rapor geçmişi değiştirilemez' using errcode='55000';
end $$;
drop trigger if exists referee_event_immutable on public.match_live_events;
create trigger referee_event_immutable before update or delete on public.match_live_events for each row execute function public._referee_journal_immutable();
drop trigger if exists referee_report_immutable on public.referee_match_reports;
create trigger referee_report_immutable before update or delete on public.referee_match_reports for each row execute function public._referee_journal_immutable();

do $$ declare r record;begin
  for r in select p.oid::regprocedure sig,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('_referee_controller','_referee_require','_referee_state','_referee_context','_referee_revision_athletes','_referee_journal_immutable',
      'referee_lineup_candidates','referee_match_state','referee_append_match_event','referee_submit_match_report') loop
    execute format('revoke all on function %s from public,anon,authenticated',r.sig);
    if r.proname in ('referee_lineup_candidates','referee_match_state','referee_append_match_event','referee_submit_match_report') then execute format('grant execute on function %s to authenticated',r.sig);end if;
  end loop;
end $$;

insert into public.feature_flags(key,audience,label) values('referee_cockpit','admins','Mobil Hakem Kokpiti') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,audience,feature,route,sort_order)
select 'Hakem kokpiti nedir ve esame nasıl onaylanır?',
  'Profildeki Hakem Kokpitinde görevi kabul et. Başhakem veya masa hakemi maçın yayımlanmış kadrosundan sahaya çıkanları ve yedekleri seçip esameyi kilitler. Tıbbi, idari veya disiplin engeli olan sporcu seçilemez. Canlı olaylar çevrimiçi sunucuda kaydolur; geri alma yeni bir olaydır. Futbol ve basketbolda sayı, teniste oyun sayısı girilir ve tamamlanan set kapatılır. Süreyi durdurup raporu imzalamak resmi sonuç üretir; tescil sonrası düzeltmeyi federasyon yapar. Bağlantı belirsizse aynı işlemi tekrar dene; kayıt onayı olmadan maç tamamlanmış sayılmaz.',
  'Müsabaka','everyone','referee_cockpit','/hakem/gorevler',140
where not exists(select 1 from public.faq_entries where feature='referee_cockpit');
create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'referee_assignment'        then '/hakem/gorevler'
    when 'match_result'              then '/resmi-sonuc'
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    when 'store_decision'            then '/magaza-basvuru'
    when 'moderation'                then '/pazaryeri'
    when 'expense_approval'          then '/mali-isler'
    when 'expense_rejected'          then '/mali-isler'
    when 'commitment_due'            then '/mali-isler'
    when 'account_negative'          then '/mali-isler'
    when 'bank_unmatched'            then '/mali-isler'
    when 'period_closed'             then '/mali-isler'
    when 'period_blocked'            then '/mali-isler'
    when 'mention'                   then '/akis'
    when 'post_repost'               then '/akis'
    when 'post_quote'                then '/akis'
    when 'support'                   then '/destek'
    when 'eligibility'               then '/athletes'
    -- 0073
    when 'training_session'          then '/antrenman-oturumu'
    when 'training_result'           then '/antrenman-sonuc'
    when 'court_waitlist' then '/saha-islemlerim'
    when 'turf_delegation' then '/saha-islemlerim'
    else '/bildirimler'
  end;
$fn$;
