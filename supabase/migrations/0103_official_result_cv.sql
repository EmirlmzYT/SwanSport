-- Rich protocols remain private. Anonymous readers keep the 0097/0098 projection.
set local lock_timeout = '15s';
alter table public.org_result_revisions add column if not exists match_protocol jsonb;

create or replace function public._official_int(p jsonb,p_path text,p_min int default 0,p_max int default 999999)
returns int language plpgsql immutable set search_path=public as $$
begin
 if jsonb_typeof(p) is distinct from 'number' then raise exception '%: tamsayı gerekli',p_path; end if;
 if p::text !~ '^[0-9]{1,12}$' then raise exception '%: tamsayı gerekli',p_path; end if;
 if p::text::numeric not between p_min and p_max then raise exception '%: sayı sınır dışında',p_path; end if;
 return p::text::int;
end $$;

-- Validate the finished outcome on the server as well as in the pure Dart engine.
create or replace function public._official_projection(s text,p jsonb)
returns jsonb language plpgsql immutable set search_path=public as $$
declare x jsonb;series_value jsonb;rows jsonb;h int:=0;a int:=0;hh int;aa int;i int:=0;n int;b int;
 ph int:=0;pa int:=0;nh int:=0;na int:=0;done boolean:=false;first_team text;
 entries jsonb:='[]';v int;r int;dq boolean;dnf boolean;seen text[]:='{}';lanes text[]:='{}';k text;
begin
 if octet_length(p::text)>100000 then raise exception 'Protokol çok büyük'; end if;
 if jsonb_typeof(p) is distinct from 'object' or p->>'status' is distinct from 'finished'
 or (p ? 'sport_code' and p->>'sport_code' is distinct from s) then raise exception 'Bitmiş, doğru branşta protokol gerekli'; end if;
 if s='basketbol' then
  if p-array['sport_code','status','periods','players']<>'{}' then raise exception 'Bilinmeyen protokol alanı'; end if;
  rows:=p->'periods';
 elsif s='futbol' then
  if p-array['sport_code','status','halves','extra_time','knockout','penalties','goals','cards']<>'{}' then raise exception 'Bilinmeyen protokol alanı'; end if;
  rows:=p->'halves';
 elsif s='tenis' then
  if p-array['sport_code','status','best_of','sets']<>'{}' then raise exception 'Bilinmeyen protokol alanı'; end if;
  b:=public._official_int(p->'best_of','best_of',3,5);
  if b not in(3,5) then raise exception 'best_of: 3 veya 5'; end if;
  rows:=p->'sets';
 elsif s in('yuzme','atletizm','okculuk') then
  if p-array['sport_code','status','performances']<>'{}' then raise exception 'Bilinmeyen protokol alanı'; end if;
  rows:=p->'performances';
 else raise exception 'Desteklenmeyen branş'; end if;
 if jsonb_typeof(rows) is distinct from 'array' then raise exception 'Sonuç satırları gerekli'; end if;
 n:=jsonb_array_length(rows);
 if n not between 1 and 200 then raise exception '1..200 sonuç satırı gerekli'; end if;
 for x in select value from jsonb_array_elements(rows) loop
  i:=i+1;
  if jsonb_typeof(x) is distinct from 'object' then raise exception 'Sonuç satırı nesne olmalı'; end if;
  if s in('basketbol','futbol','tenis') then
   hh:=public._official_int(x->'home','home');aa:=public._official_int(x->'away','away');
   if s='basketbol' then
    if x-array['label','home','away','team_fouls']<>'{}' then raise exception 'Bilinmeyen periyot alanı'; end if;
    if x->>'label' is distinct from (case when i<=4 then 'Q'||i else 'OT'||(i-4) end)
    or (i>4 and h<>a) then raise exception 'Periyot sırası/uzatma geçersiz'; end if;
    if x ? 'team_fouls' then
     if (x->'team_fouls')-array['home','away']<>'{}' then raise exception 'Bilinmeyen faul alanı'; end if;
     perform public._official_int(x->'team_fouls'->'home','team_fouls.home');
     perform public._official_int(x->'team_fouls'->'away','team_fouls.away');
    else raise exception 'Takım faulleri gerekli';end if;
    h:=h+hh;a:=a+aa;
   elsif s='futbol' then
    if x-array['home','away']<>'{}' then raise exception 'Bilinmeyen devre alanı'; end if;
    h:=h+hh;a:=a+aa;
   else
    if x-array['home','away','tie_break','tie_break_target']<>'{}' then raise exception 'Bilinmeyen set alanı'; end if;
    if h>=b/2+1 or a>=b/2+1 then raise exception 'Maç bittikten sonra set eklenemez'; end if;
    if not ((greatest(hh,aa)=6 and least(hh,aa)<=4) or (greatest(hh,aa)=7 and least(hh,aa) in(5,6))) then raise exception 'Tamamlanmış tenis seti gerekli'; end if;
    if x ? 'tie_break' or least(hh,aa)=6 then
     if (x->'tie_break')-array['home','away']<>'{}' then raise exception 'Bilinmeyen tie-break alanı';end if;
     ph:=public._official_int(x->'tie_break'->'home','tie_break.home');
     pa:=public._official_int(x->'tie_break'->'away','tie_break.away');
     v:=public._official_int(coalesce(x->'tie_break_target','7'),'tie_break_target');
     if v not in(7,10) or greatest(hh,aa)<>7 or least(hh,aa)<>6
      or greatest(ph,pa)<>greatest(v,least(ph,pa)+2) or ((ph>pa)<>(hh>aa)) then raise exception 'Tie-break geçersiz'; end if;
    end if;
    if hh>aa then h:=h+1;else a:=a+1;end if;
    entries:=entries||jsonb_build_array(jsonb_build_object('home',hh,'away',aa));
   end if;
  else
   if x-array['athlete_ref','lane','heat','time_ms','rank','dq','dnf','series']<>'{}' then raise exception 'Bilinmeyen derece alanı'; end if;
   if (s='okculuk' and x ? 'time_ms') or (s<>'okculuk' and x ? 'series') then raise exception 'Branş derece alanı uyuşmuyor';end if;
   if not coalesce((x->>'athlete_ref')~'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',false) then raise exception 'Sporcu referansı geçersiz'; end if;
   hh:=public._official_int(x->'heat','heat',1);aa:=public._official_int(x->'lane','lane',1);
   k:=(x->>'athlete_ref')||':'||hh;
   if k=any(seen) or (hh||':'||aa)=any(lanes) then raise exception 'Seride sporcu/kulvar tekrarı'; end if;
   seen:=array_append(seen,k);lanes:=array_append(lanes,hh||':'||aa);
   if (x ? 'dq' and jsonb_typeof(x->'dq')<>'boolean') or (x ? 'dnf' and jsonb_typeof(x->'dnf')<>'boolean') then raise exception 'DQ/DNF boolean olmalı'; end if;
   dq:=coalesce((x->>'dq')::boolean,false);dnf:=coalesce((x->>'dnf')::boolean,false);
   if dq and dnf then raise exception 'DQ ve DNF birlikte olamaz'; end if;
   if dq or dnf then
    if x->'time_ms' is not null and x->'time_ms'<>'null' or x->'rank' is not null and x->'rank'<>'null' or x ? 'series' then raise exception 'DQ/DNF derece taşıyamaz'; end if;
   else
    r:=public._official_int(x->'rank','rank',1);
    if s='okculuk' then
     if jsonb_typeof(x->'series') is distinct from 'array' then raise exception 'Seri puanları gerekli'; end if;
     if jsonb_array_length(x->'series') not between 1 and 100 then raise exception '1..100 seri gerekli'; end if;
     v:=0;for series_value in select value from jsonb_array_elements(x->'series') loop v:=v+public._official_int(series_value,'series',0,360);end loop;
    else v:=public._official_int(x->'time_ms','time_ms',1,2147483647);end if;
    entries:=entries||jsonb_build_array(jsonb_build_object('athlete_id',x->>'athlete_ref','value',v,'placement',r));
   end if;
  end if;
 end loop;
 if s='basketbol' then
  if n<4 or n>24 or h=a then raise exception 'Basketbol: dört periyot, beraberlikte uzatma gerekli'; end if;
  rows:=coalesce(p->'players','[]');
  if jsonb_typeof(rows) is distinct from 'array' then raise exception 'Oyuncu istatistikleri liste olmalı';end if;
  for x in select value from jsonb_array_elements(rows) loop
   if x-array['player_ref','team','points','rebounds','assists','fouls']<>'{}' then raise exception 'Bilinmeyen oyuncu alanı';end if;
   if coalesce(x->>'team','') not in('home','away') or (x->>'player_ref')=any(seen) then raise exception 'Oyuncu takımı/tekrarı geçersiz';end if;
   seen:=array_append(seen,x->>'player_ref');
   v:=public._official_int(x->'points','points');
   if x->>'team'='home' then ph:=ph+v;else pa:=pa+v;end if;
   perform public._official_int(x->'rebounds','rebounds');perform public._official_int(x->'assists','assists');perform public._official_int(x->'fouls','fouls');
  end loop;
  if ph>h or pa>a then raise exception 'Oyuncu sayıları toplam skoru aşamaz';end if;
 elsif s='futbol' then
  if n<>2 then raise exception 'İki devre gerekli'; end if;
  if p ? 'knockout' and jsonb_typeof(p->'knockout')<>'boolean' then raise exception 'knockout boolean olmalı'; end if;
  rows:=coalesce(p->'extra_time','[]');
  if jsonb_typeof(rows)<>'array' then raise exception 'Uzatma liste olmalı'; end if;
  if jsonb_array_length(rows) not in(0,2) or (jsonb_array_length(rows)>0 and (h<>a or not coalesce((p->>'knockout')::boolean,false))) then raise exception 'Uzatma geçersiz'; end if;
  for x in select value from jsonb_array_elements(rows) loop
   if x-array['home','away']<>'{}' then raise exception 'Bilinmeyen uzatma alanı';end if;
   h:=h+public._official_int(x->'home','extra.home');a:=a+public._official_int(x->'away','extra.away');
  end loop;
  rows:=coalesce(p->'penalties','[]');
  if jsonb_typeof(rows)<>'array' or jsonb_array_length(rows)>100 then raise exception 'Penaltı listesi geçersiz'; end if;
  if jsonb_array_length(rows)>0 and (h<>a or not coalesce((p->>'knockout')::boolean,false)) then raise exception 'Penaltı için berabere eleme maçı gerekli'; end if;
  ph:=0;pa:=0;i:=0;
  for x in select value from jsonb_array_elements(rows) loop
   if x-array['team','scored']<>'{}' then raise exception 'Bilinmeyen penaltı alanı';end if;
   if done then raise exception 'Penaltı serisi tamamlandı'; end if;
   i:=i+1;
   if i=1 then first_team:=x->>'team';end if;
   if coalesce(x->>'team','') not in('home','away') or jsonb_typeof(x->'scored') is distinct from 'boolean'
    or x->>'team' is distinct from (case when i%2=1 then first_team when first_team='home' then 'away' else 'home' end) then raise exception 'Penaltı sırası geçersiz'; end if;
   if x->>'team'='home' then nh:=nh+1;ph:=ph+case when (x->>'scored')::boolean then 1 else 0 end;
   else na:=na+1;pa:=pa+case when (x->>'scored')::boolean then 1 else 0 end;end if;
   done:=(nh<=5 and na<=5 and (ph>pa+5-na or pa>ph+5-nh)) or (nh>=5 and nh=na and ph<>pa);
  end loop;
  if coalesce((p->>'knockout')::boolean,false) and h=a and not done then raise exception 'Eleme maçı sonuçlanmadı'; end if;
  ph:=0;pa:=0;
  for k in select unnest(array['goals','cards']) loop
   rows:=coalesce(p->k,'[]');
   if jsonb_typeof(rows) is distinct from 'array' then raise exception 'Gol/kart liste olmalı';end if;
   for x in select value from jsonb_array_elements(rows) loop
    if x-array['minute','added_time','player_ref','team','card']<>'{}' or coalesce(x->>'team','') not in('home','away') then raise exception 'Gol/kart alanı geçersiz';end if;
    perform public._official_int(x->'minute','minute',1,case when jsonb_array_length(coalesce(p->'extra_time','[]'))>0 then 120 else 90 end);
    perform public._official_int(coalesce(x->'added_time','0'),'added_time');
    if k='cards' and coalesce(x->>'card','') not in('yellow','red') then raise exception 'Kart yellow/red olmalı';end if;
    if k='goals' then if x->>'team'='home' then ph:=ph+1;else pa:=pa+1;end if;end if;
   end loop;
  end loop;
  if ph>h or pa>a then raise exception 'Goller maç skorunu aşamaz';end if;
 elsif s='tenis' then
  if n>b or greatest(h,a)<>b/2+1 then raise exception 'Maç kazanılacak set sayısına ulaşmadı'; end if;
  return jsonb_build_object('type','sets','sets',entries);
 else
  -- Competition ranks per heat: equal times in swimming share rank; athletics
  -- permits official photo-finish ordering. Archery equal totals may use tie-break rank.
  for x in select value from jsonb_array_elements(p->'performances') where coalesce((value->>'dq')::boolean,false)=false and coalesce((value->>'dnf')::boolean,false)=false loop
   r:=(x->>'rank')::int;
   select count(*)+1 into v from jsonb_array_elements(p->'performances') y
   where y->>'heat'=x->>'heat' and not coalesce((y->>'dq')::boolean,false) and not coalesce((y->>'dnf')::boolean,false)
    and (y->>'rank')::int<r;
   if v<>r then raise exception 'Seri sıralaması kesintisiz olmalı (eşitlikte 1,1,3)'; end if;
   if s='okculuk' and exists(select 1 from jsonb_array_elements(p->'performances') y
    where y->>'heat'=x->>'heat' and not coalesce((y->>'dq')::boolean,false) and not coalesce((y->>'dnf')::boolean,false)
    and ((select sum(value::text::int) from jsonb_array_elements(y->'series')) > (select sum(value::text::int) from jsonb_array_elements(x->'series')) and (y->>'rank')::int>=r
      or (select sum(value::text::int) from jsonb_array_elements(y->'series')) < (select sum(value::text::int) from jsonb_array_elements(x->'series')) and (y->>'rank')::int<=r)) then raise exception 'Puan ve sıra uyuşmuyor';end if;
   if s<>'okculuk' and exists(select 1 from jsonb_array_elements(p->'performances') y where y->>'heat'=x->>'heat'
    and not coalesce((y->>'dq')::boolean,false) and not coalesce((y->>'dnf')::boolean,false)
    and (((y->>'time_ms')::bigint<(x->>'time_ms')::bigint and (y->>'rank')::int>=r)
      or (s='yuzme' and (y->>'time_ms')::bigint=(x->>'time_ms')::bigint and (y->>'rank')::int<>r))) then raise exception 'Derece ve sıra uyuşmuyor'; end if;
  end loop;
  return jsonb_build_object('type',case when s='okculuk' then 'rank' else 'time' end,'entries',entries);
 end if;
 if h>999999 or a>999999 then raise exception 'Toplam skor sınır dışında'; end if;
 return jsonb_build_object('type','score','home',h,'away',a);
end $$;

-- Only the trusted writer calls this helper. No client-supplied title/medal.
create or replace function public._federation_result_cv(p_revision uuid)
returns void language plpgsql security definer set search_path=public as $$
declare rv public.org_result_revisions;m public.org_matches;o public.organizations;k uuid;prev uuid;title text;pos int;detail text;home boolean;h int;a int;x jsonb;
begin
 select * into rv from public.org_result_revisions where id=p_revision;
 select * into m from public.org_matches where id=rv.match_id;
 select * into o from public.organizations where id=m.org_id and official;
 perform public._federation_require(o.sport_code,o.city_code,'result_publisher');
 for k in select distinct unnest(r.athlete_ids) from public.org_roster_revisions r where r.id in(rv.home_roster_revision_id,rv.away_roster_revision_id) loop
  pos:=null;detail:=null;
  if rv.protocol->>'type' in('time','rank') then
   select min((e->>'placement')::int),string_agg((e->>'placement')||'. / '||(e->>'value')||case when rv.protocol->>'type'='time' then ' ms' else ' puan' end,'; ' order by ord)
    into pos,detail from jsonb_array_elements(rv.protocol->'entries') with ordinality z(e,ord) where e->>'athlete_id'=k::text;
   if detail is null then continue;end if;
   if (select count(*) from jsonb_array_elements(rv.protocol->'entries') e where e->>'athlete_id'=k::text)>1 then pos:=null;end if;
   if rv.match_protocol is not null then
    select string_agg('Seri '||(e->>'heat')||' · '||(e->>'rank')||'. / '||
      case when o.sport_code='okculuk' then (select sum(value::text::int)::text from jsonb_array_elements(e->'series'))||' puan'
      else (e->>'time_ms')||' ms' end,'; ' order by ord) into detail
      from jsonb_array_elements(rv.match_protocol->'performances') with ordinality z(e,ord)
      where e->>'athlete_ref'=k::text and not coalesce((e->>'dq')::boolean,false) and not coalesce((e->>'dnf')::boolean,false);
   end if;
   title:=left(o.name,120)||' — seri sonucu';
  else
   if rv.protocol->>'type'='sets' then
    select count(*) filter(where (e->>'home')::int>(e->>'away')::int),count(*) filter(where (e->>'away')::int>(e->>'home')::int) into h,a from jsonb_array_elements(rv.protocol->'sets') e;
   else h:=(rv.protocol->>'home')::int;a:=(rv.protocol->>'away')::int;end if;
   if rv.match_protocol->>'sport_code'='futbol' and jsonb_array_length(coalesce(rv.match_protocol->'penalties','[]'))>0 then
    select count(*) filter(where e->>'team'='home' and (e->>'scored')::boolean),count(*) filter(where e->>'team'='away' and (e->>'scored')::boolean) into h,a from jsonb_array_elements(rv.match_protocol->'penalties') e;
    detail:='Seri penaltı '||h||'–'||a;
   else detail:=h||'–'||a;end if;
   select k=any(r.athlete_ids) into home from public.org_roster_revisions r where r.id=rv.home_roster_revision_id;
   title:=left(o.name,120)||' — '||case when h=a then 'Maç beraberliği' when (home and h>a) or (not home and a>h) then 'Maç galibiyeti' else 'Resmi maç kadrosu' end;
  end if;
  select ac.id into prev from public.athlete_achievements ac join public.org_result_revisions rr on rr.id=ac.source_id
   where ac.athlete_id=k and ac.source='federation_result' and ac.official_match_id=m.id and rr.version<rv.version
   and not exists(select 1 from public.athlete_achievements successor where successor.supersedes_id=ac.id)
   order by rr.version desc limit 1;
  insert into public.athlete_achievements(athlete_id,title,category,placement,event_date,location,note,source,source_id,official_match_id,supersedes_id,verified,created_by)
   values(k,title,'derece',pos,(m.starts_at at time zone 'Europe/Istanbul')::date,m.location,detail,'federation_result',rv.id,m.id,prev,true,auth.uid());
 end loop;
end $$;
create or replace function public._federation_commit_result(p_match uuid,p_protocol jsonb,p_reason text,p_expected_version int,p_raw jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare m public.org_matches;o public.organizations;a uuid;v uuid;home_roster uuid;away_roster uuid;
begin
 select * into m from public.org_matches where id=p_match for update;
 select * into o from public.organizations where id=m.org_id and official;
 a:=public._federation_require(o.sport_code,o.city_code,'result_publisher');
 if m.result_version is distinct from p_expected_version then raise exception 'Sonuç sürümü değişti'; end if;
 if m.status='cancelled' then raise exception 'İptal edilmiş müsabaka yayımlanamaz'; end if;
 if (p_raw is null and not public._valid_official_protocol(p_protocol)) or p_reason is null or length(trim(p_reason)) not between 1 and 500 then raise exception 'Sonuç protokolü/gerekçe geçersiz'; end if;
 -- Serialize roster publication with the result snapshot; fixed UUID order avoids reversed-side deadlocks.
 perform 1 from public.org_participants where id in(m.home_id,m.away_id) order by id for share;
 select id into home_roster from public.org_roster_revisions where participant_id=m.home_id order by version desc limit 1;
 select id into away_roster from public.org_roster_revisions where participant_id=m.away_id order by version desc limit 1;
 if home_roster is null or (m.away_id is not null and away_roster is null) then raise exception 'Önce resmi kadro yayımlanmalı'; end if;
 if p_protocol->>'type' in ('time','rank') and exists(select 1 from jsonb_array_elements(p_protocol->'entries') e
 where not exists(select 1 from public.org_roster_revisions r where r.participant_id in(m.home_id,m.away_id)
 and r.version=(select max(r2.version) from public.org_roster_revisions r2 where r2.participant_id=r.participant_id)
 and (e->>'athlete_id')::uuid=any(r.athlete_ids))) then raise exception 'Sonuç sporcusu güncel resmi kadroda yok'; end if;
 insert into public.org_result_revisions(match_id,version,protocol,reason,actor_id,home_roster_revision_id,away_roster_revision_id,match_protocol) values(m.id,m.result_version+1,p_protocol,p_reason,auth.uid(),home_roster,away_roster,p_raw) returning id into v;
 update public.org_matches set result_protocol=p_protocol,result_version=m.result_version+1,status='played',
 home_score=case when p_protocol->>'type'='score' then (p_protocol->>'home')::int end,
 away_score=case when p_protocol->>'type'='score' then (p_protocol->>'away')::int end where id=m.id;
 perform public._federation_result_cv(v);
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail) values(auth.uid(),a,'result_revision',v,jsonb_build_object('version',m.result_version+1));return v;
end $$;

-- Existing signature remains available. Its new results also receive automatic CV entries.
create or replace function public.federation_publish_result(p_match uuid,p_protocol jsonb,p_reason text,p_expected_version int)
returns uuid language sql security definer set search_path=public as $$
 select public._federation_commit_result(p_match,p_protocol,p_reason,p_expected_version,null)
$$;

create or replace function public.publish_official_match_result(p_match uuid,p_protocol jsonb,p_reason text,p_expected_version int)
returns uuid language plpgsql security definer set search_path=public as $$
declare s text;c text;compact jsonb;m public.org_matches;x jsonb;
begin
 select * into m from public.org_matches where id=p_match for update;
 select o.sport_code,o.city_code into s,c from public.organizations o where o.id=m.org_id and o.official;
 perform public._federation_require(s,c,'result_publisher');
 if s in('basketbol','futbol','tenis') and (m.home_id is null or m.away_id is null or m.home_id=m.away_id) then raise exception 'İki farklı resmi katılımcı gerekli'; end if;
 compact:=public._official_projection(s,p_protocol);
 -- Validate every reference, including DQ/DNF entries which are absent from compact results.
 perform 1 from public.org_participants where id in(m.home_id,m.away_id) order by id for share;
 if s in('yuzme','atletizm','okculuk') then
  for x in select value from jsonb_array_elements(p_protocol->'performances') loop
   if not exists(select 1 from public.org_roster_revisions r where r.participant_id in(m.home_id,m.away_id)
     and r.version=(select max(r2.version) from public.org_roster_revisions r2 where r2.participant_id=r.participant_id)
     and (x->>'athlete_ref')::uuid=any(r.athlete_ids)) then raise exception 'Sonuç sporcusu güncel resmi kadroda yok'; end if;
  end loop;
 end if;
 -- Optional player statistics and incidents must reference the declared side's roster.
 for x in select value from jsonb_array_elements(coalesce(p_protocol->'players','[]')||coalesce(p_protocol->'goals','[]')||coalesce(p_protocol->'cards','[]')) loop
  if not coalesce((x->>'player_ref')~'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',false) then raise exception 'Oyuncu referansı geçersiz';end if;
  if not exists(select 1 from public.org_roster_revisions r where r.participant_id=case when x->>'team'='home' then m.home_id else m.away_id end
   and r.version=(select max(r2.version) from public.org_roster_revisions r2 where r2.participant_id=r.participant_id)
   and (x->>'player_ref')::uuid=any(r.athlete_ids)) then raise exception 'Oyuncu belirtilen tarafın resmi kadrosunda yok';end if;
 end loop;
 return public._federation_commit_result(p_match,compact,p_reason,p_expected_version,p_protocol||jsonb_build_object('sport_code',s));
end $$;

-- RLS is intentionally unchanged: private CV is an explicit, authenticated projection.
create or replace function public._official_cv_access(p_athlete uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and exists(select 1 from public.athletes a where a.id=p_athlete and
  (a.profile_id=auth.uid() or public.is_club_staff(a.club_id)
   or exists(select 1 from public.guardians g where g.athlete_id=a.id and g.profile_id=auth.uid())))
$$;

create or replace function public.official_athlete_achievements(p_athlete uuid)
returns table(id uuid,athlete_id uuid,title text,category text,placement int,event_date date,location text,note text,
 source text,official_match_id uuid,source_id uuid,sport_code text,match_name text,result_version int)
language plpgsql stable security definer set search_path=public as $$
begin
 if not coalesce(public._official_cv_access(p_athlete),false) then raise exception 'Sportif sicil erişimi gerekli' using errcode='42501';end if;
 return query select ac.id,ac.athlete_id,ac.title,ac.category,ac.placement,ac.event_date,ac.location,ac.note,
 ac.source,ac.official_match_id,ac.source_id,o.sport_code,o.name,rv.version
 from public.athlete_achievements ac join public.org_result_revisions rv on rv.id=ac.source_id and rv.match_id=ac.official_match_id
 join public.org_matches m on m.id=rv.match_id and m.result_version=rv.version
 join public.organizations o on o.id=m.org_id and o.official
 where ac.athlete_id=p_athlete and ac.source='federation_result'
 order by ac.event_date desc nulls last,ac.id;
end $$;

-- The source detail projects numeric score lines, never full raw player/roster data.
create or replace function public._official_source_scores(s text,p jsonb,compact jsonb)
returns jsonb language plpgsql immutable set search_path=public as $$
declare rows jsonb;result jsonb:='[]';x jsonb;i int:=0;label text;
begin
 if s='basketbol' then rows:=p->'periods';
 elsif s='futbol' then rows:=coalesce(p->'halves','[]')||coalesce(p->'extra_time','[]');
 elsif s='tenis' then rows:=compact->'sets';
 elsif compact->>'type'='score' then rows:=jsonb_build_array(compact);
 else return result;end if;
 for x in select value from jsonb_array_elements(coalesce(rows,'[]')) loop
  i:=i+1;label:=case when s='basketbol' then x->>'label' when s='futbol' then case when i<=2 then i||'. Devre' else 'Uzatma '||(i-2) end when s='tenis' then 'Set '||i else 'Skor' end;
  result:=result||jsonb_build_array(jsonb_build_object('label',label,'home',(x->>'home')::int,'away',(x->>'away')::int));
 end loop;
 return result;
end $$;

create or replace function public.official_achievement_source(p_achievement uuid)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare ac public.athlete_achievements;result jsonb;
begin
 select * into ac from public.athlete_achievements where id=p_achievement and source='federation_result';
 if not coalesce(public._official_cv_access(ac.athlete_id),false) then raise exception 'Sportif sicil erişimi gerekli' using errcode='42501';end if;
 select jsonb_build_object('match_id',m.id,'name',o.name,'sport_code',o.sport_code,'starts_at',ac.event_date,
 'location',ac.location,'version',rv.version,'current_version',m.result_version,'result',ac.note,'placement',ac.placement,'scores',public._official_source_scores(o.sport_code,rv.match_protocol,rv.protocol))
 into result from public.org_result_revisions rv join public.org_matches m on m.id=rv.match_id
 join public.organizations o on o.id=m.org_id and o.official where rv.id=ac.source_id and m.id=ac.official_match_id;
 return result;
end $$;

create or replace function public.federation_pending_results(p_offset int default 0,p_limit int default 100)
returns table(match_id uuid,org_name text,sport_code text,city_code text,starts_at timestamptz,location text,
 home_name text,away_name text,version int)
language sql stable security definer set search_path=public as $$
 select m.id,o.name,o.sport_code,o.city_code,m.starts_at,m.location,h.legal_name,a.legal_name,m.result_version
 from public.org_matches m join public.organizations o on o.id=m.org_id and o.official
 left join public.org_participants hp on hp.id=m.home_id left join public.clubs h on h.id=hp.club_id
 left join public.org_participants ap on ap.id=m.away_id left join public.clubs a on a.id=ap.club_id
 where m.status='scheduled' and m.result_version=0 and exists(
  select 1 from public.federation_appointments fa join public.federation_offices fo on fo.id=fa.office_id
  join public.federations f on f.id=fo.federation_id where fa.profile_id=auth.uid() and fa.duty='result_publisher'
  and fa.revoked_at is null and (now() at time zone 'Europe/Istanbul')::date between fa.starts_on and fa.ends_on
  and f.sport_code=o.sport_code and (fo.city_code is null or fo.city_code=o.city_code))
 order by m.starts_at nulls last,m.id limit least(greatest(p_limit,1),100) offset greatest(p_offset,0)
$$;

-- Append-only protocol history, including owner/server mistakes. FK cleanup may null the actor only.
create or replace function public._official_revision_immutable()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='UPDATE' and pg_trigger_depth()>1 and new.actor_id is null
  and (to_jsonb(new)-'actor_id')=(to_jsonb(old)-'actor_id') then return new;end if;
 raise exception 'Resmi sonuç revizyonu değiştirilemez';
end $$;
drop trigger if exists official_revision_immutable on public.org_result_revisions;
create trigger official_revision_immutable before update or delete on public.org_result_revisions
 for each row execute function public._official_revision_immutable();

-- Default PUBLIC execute is always removed, including for internal helpers.
do $$ declare r record;begin
 for r in select p.oid::regprocedure sig,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in('_official_int','_official_projection','_federation_result_cv','_federation_commit_result',
 '_official_cv_access','_official_source_scores','_official_revision_immutable','publish_official_match_result','federation_publish_result',
 'official_athlete_achievements','official_achievement_source','federation_pending_results') loop
  execute format('revoke all on function %s from public,anon,authenticated',r.sig);
  if r.proname in('publish_official_match_result','federation_publish_result','official_athlete_achievements','official_achievement_source','federation_pending_results') then
   execute format('grant execute on function %s to authenticated',r.sig);
  end if;
 end loop;
end $$;

-- Reduced SQL test fixtures omit FAQ infrastructure; the full product has it.
do $faq$ begin
 if to_regclass('public.faq_entries') is not null then
  insert into public.faq_entries(question,answer,category,audience,sort_order,route)
  select 'Resmi Federasyon Derecesi nasıl oluşur?',
   'Görevli federasyon sonuç yayımlayıcısı resmi kadroya bağlı sonucu onayladığında sicil otomatik oluşur. Yeşil kalkan resmi kaynağı gösterir; kulüp beyanları ayrı listelenir. Tek maç galibiyeti şampiyonluk sayılmaz. Seri dereceleri kendi serisine aittir. Sporcu ve kulüp resmi kaydı düzenleyemez veya silemez. Federasyon düzeltmesi yeni sonuç revizyonu oluşturur; profil güncel revizyonu gösterir. Karttan kaynak müsabakayı açabilirsin. Resmi sicile sporcu, bağlı veli ve yetkili kulüp personeli erişebilir; misafirler yalnız yayımlanmış programın genel sonucunu okuyabilir.',
   'Genel','everyone',103,'/profil'
  where not exists(select 1 from public.faq_entries where question='Resmi Federasyon Derecesi nasıl oluşur?');
 end if;
end $faq$;
