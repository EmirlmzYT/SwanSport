set local lock_timeout = '15s';
-- Existing generic non-target phase/submission paths in 0105 support the new metrics.
-- No RPC signature, RLS, C1 gate or lock-order changes.
-- Structured sets represent one result, not target-score units. Explicit phase
-- overrides must obey the same archetype restrictions as automatic transitions.
create or replace function public.advance_session_phase(
  p_session uuid,
  p_phase text default null,
  p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare v_s    public.training_sessions%rowtype;
        v_cfg  jsonb;
        v_next jsonb;
        v_ph   text;
        v_set  int;
        v_secs int;
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumu yönetme yetkin yok';
  end if;

  select * into v_s from public.training_sessions where id = p_session for update;
  if v_s.status <> 'live' then
    raise exception 'Oturum canlı değil';
  end if;

  select config into v_cfg from public.training_protocols where id = v_s.protocol_id;

  if p_phase is null then
    v_next := public.training_next_phase(v_s.current_phase, v_s.current_set, v_cfg);
    v_ph   := v_next->>'phase';
    v_set  := (v_next->>'set_no')::numeric::int;
  else
    if p_phase not in ('prep','shoot','collect','score','rest','done','active_drill','lap_active','rest_interval') then
      raise exception 'Geçersiz aşama';
    end if;
    if coalesce(v_cfg->>'archetype','target_score')='target_score' and p_phase in ('active_drill','lap_active','rest_interval')
      or coalesce(v_cfg->>'archetype','target_score') in ('attempt_drill','combat_rally','strength_set','routine_judge','mind_tactical') and p_phase in ('shoot','collect','score','lap_active','rest_interval')
      or v_cfg->>'archetype'='lap_interval' and p_phase in ('shoot','collect','score','active_drill','rest') then
      raise exception 'Arketip için geçersiz aşama';
    end if;
    v_ph  := p_phase;
    v_set := v_s.current_set;
  end if;

  v_secs := public.training_phase_seconds(v_ph, v_cfg);

  update public.training_sessions
     set current_phase = v_ph,
         current_set   = v_set,
         phase_started_at = now(),
         phase_ends_at = case when coalesce(v_secs, 0) > 0
                              then now() + make_interval(secs => v_secs) end,
         paused_at = null,
         status    = case when v_ph = 'done' then 'review' else status end,
         ended_at  = case when v_ph = 'done' then now() else ended_at end
   where id = p_session;

  insert into public.training_session_events
    (session_id, actor_id, action, reason, phase, set_no, old_value, new_value)
  values (p_session, auth.uid(),
          case when p_phase is null then 'advance' else 'skip' end,
          nullif(trim(coalesce(p_reason, '')), ''), v_ph, v_set,
          jsonb_build_object('phase', v_s.current_phase, 'set_no', v_s.current_set),
          jsonb_build_object('phase', v_ph, 'set_no', v_set));

  return jsonb_build_object('phase', v_ph, 'set_no', v_set);
end;
$fn$;


create or replace function public.session_summary(p_session uuid)
returns table (
  athlete_id      uuid,
  athlete_name    text,
  lane            int,
  sets_done       int,
  sets_expected   int,
  total_score     numeric,
  avg_set         numeric,
  best_set        numeric,
  missing_sets    int,
  units_recorded  int,
  units_expected  int,
  progression     numeric[],
  score_buckets   jsonb,
  rpe             int,
  locked          boolean,
  review_flags    text[])
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumun sonuçlarını görme yetkin yok';
  end if;

  return query
  with cfg as (
    select (pr.config->>'set_count')::numeric::int     as set_count,
           case when pr.config->>'archetype' in ('lap_interval','strength_set','routine_judge','mind_tactical') then 1 else (pr.config->>'units_per_set')::numeric::int end as units_per_set
      from public.training_sessions s
      join public.training_protocols pr on pr.id = s.protocol_id
     where s.id = p_session
  ),
  sets as (
    select t.athlete_id,
           count(*) filter (where t.total_score is not null or t.metric_payload <> '{}'::jsonb)::int as done,
           sum(t.total_score)                                     as total,
           avg(t.total_score)                                     as avg_set,
           max(t.total_score)                                     as best,
           sum(coalesce(t.unit_count, 0))::int                    as units,
           array_agg(t.total_score order by t.set_no)             as progression,
           bool_and(t.locked_at is not null)                      as locked
      from public.training_sets t
     where t.session_id = p_session
     group by t.athlete_id
  ),
  buckets as (
    select t.athlete_id,
           jsonb_object_agg(x.score, x.n) as buckets
      from public.training_sets t
      join lateral (
        select to_char(e.score, 'FM999999.##') as score, count(*)::int as n
          from public.training_set_entries e
         where e.set_id = t.id and e.score is not null
         group by e.score) x on true
     where t.session_id = p_session
     group by t.athlete_id
  )
  select p.athlete_id,
         (a.first_name || ' ' || a.last_name)::text,
         p.lane,
         coalesce(s.done, 0),
         c.set_count,
         s.total,
         round(s.avg_set, 2),
         s.best,
         greatest(c.set_count - coalesce(s.done, 0), 0),
         coalesce(s.units, 0),
         c.set_count * c.units_per_set,
         coalesce(s.progression, array[]::numeric[]),
         b.buckets,
         sa.rpe,
         coalesce(s.locked, false),
         (
           -- Antrenör inceleme uyarıları. Hepsi "bak" demek, "yanlış"
           -- demek değil.
           array_remove(array[
             case when coalesce(s.done, 0) = 0 then 'skor_yok' end,
             case when coalesce(s.done, 0) between 1 and c.set_count - 1
                  then 'eksik_set' end,
             case when coalesce(s.units, 0) > 0
                   and s.units < c.set_count * c.units_per_set / 2
                  then 'az_atis' end,
             case when array_length(s.progression, 1) >= 3
                   and s.progression[array_length(s.progression, 1)] is not null
                   and s.progression[array_length(s.progression, 1) - 1] is not null
                   and s.progression[array_length(s.progression, 1)]
                       < s.progression[array_length(s.progression, 1) - 1] * 0.8
                  then 'son_sette_dusus' end
           ], null)
         )::text[]
    from public.training_session_participants p
    join public.athletes a on a.id = p.athlete_id
    cross join cfg c
    left join sets s    on s.athlete_id = p.athlete_id
    left join buckets b on b.athlete_id = p.athlete_id
    left join public.training_self_assessments sa
           on sa.session_id = p_session and sa.athlete_id = p.athlete_id
   order by 2;
end;
$fn$;


create or replace function public.session_overview(p_session uuid)
returns table (
  joined_count     int,
  completed_count  int,
  no_score_count   int,
  awaiting_lock    int,
  team_total       numeric,
  session_avg      numeric,
  units_recorded   int,
  units_expected   int,
  protocol_name    text,
  protocol_version int,
  set_count        int,
  status           text)
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumun özetini görme yetkin yok';
  end if;

  return query
  with s as (select * from public.training_sessions where id = p_session),
  pr as (select p.* from public.training_protocols p
           join s on s.protocol_id = p.id),
  parts as (select count(*)::int n from public.training_session_participants
             where session_id = p_session),
  per as (
    select t.athlete_id,
           count(*) filter (where t.total_score is not null or t.metric_payload <> '{}'::jsonb)::int as done,
           bool_and(t.locked_at is not null) as locked
      from public.training_sets t where t.session_id = p_session
     group by t.athlete_id
  ),
  agg as (
    select coalesce(sum(t.total_score), 0)          as total,
           avg(t.total_score)                       as avg_all,
           coalesce(sum(t.unit_count), 0)::int      as units
      from public.training_sets t where t.session_id = p_session
  )
  select parts.n,
         (select count(*)::int from per
           where per.done >= (pr.config->>'set_count')::numeric::int),
         parts.n - (select count(*)::int from per where per.done > 0),
         (select count(*)::int from per where not per.locked),
         case when pr.config->>'archetype' in ('lap_interval','strength_set','routine_judge','mind_tactical') then null::numeric else agg.total end,
         round(agg.avg_all, 2),
         agg.units,
         parts.n * (pr.config->>'set_count')::numeric::int
                 * case when pr.config->>'archetype' in ('lap_interval','strength_set','routine_judge','mind_tactical') then 1 else (pr.config->>'units_per_set')::numeric::int end,
         pr.name,
         pr.version,
         (pr.config->>'set_count')::numeric::int,
         s.status
    from s, pr, parts, agg;
end;
$fn$;

create or replace function public.valid_training_config(p jsonb)
returns boolean language sql immutable set search_path = public as $fn$
 select coalesce(jsonb_typeof(p)='object'
   and coalesce(p->>'archetype','target_score') in ('target_score','attempt_drill','lap_interval','combat_rally','strength_set','routine_judge','mind_tactical')
   and (not (p ? 'archetype') or jsonb_typeof(p->'archetype')='string')
   and public._training_number(p,'set_count',1,50)
   and public._training_number(p,'units_per_set',1,100)
   and public._training_number(p,'prep_seconds',0,3600)
   and public._training_number(p,'shoot_seconds',5,3600)
   and public._training_number(p,'rest_seconds',0,3600)
   and public._training_number(p,'max_unit_score',1,1000,false)
   and case when coalesce(p->>'archetype','target_score')='target_score' or p ? 'collect_seconds'
     then public._training_number(p,'collect_seconds',0,3600) else true end
   and p->>'entry_mode' in ('simple','detailed','flexible')
   and p->>'mode' in ('technique','scored','simulation'),false);
$fn$;

create or replace function public.valid_drill_metric(p_archetype text, p jsonb)
returns boolean language plpgsql immutable set search_path = public as $fn$
declare k text; allowed text[];
begin
 if jsonb_typeof(p) is distinct from 'object' then return false; end if;
 if p_archetype='target_score' then
   if p='{}'::jsonb then return true; end if;
   if jsonb_typeof(p->'marks') is distinct from 'array' then return false; end if;
   if jsonb_array_length(p->'marks') not between 1 and 100 then return false; end if;
   if exists(select 1 from jsonb_array_elements(p->'marks') e where
     jsonb_typeof(e.value) is distinct from 'string' or
     (e.value #>> '{}') not in ('X','M','0','1','2','3','4','5','6','7','8','9','10')) then return false; end if;
   allowed:=array['marks'];
 elsif p_archetype='attempt_drill' then
   if jsonb_typeof(p->'drill_name') is distinct from 'string' then return false; end if;
   if length(trim(p->>'drill_name')) not between 1 and 120 then return false; end if;
   if not (public._training_number(p,'successful',0,10000) and public._training_number(p,'faults',0,10000)
     and public._training_number(p,'total_attempts',1,10000) and public._training_number(p,'success_rate',0,1,false)) then return false; end if;
   if (p->>'successful')::numeric+(p->>'faults')::numeric<>(p->>'total_attempts')::numeric
     or abs((p->>'success_rate')::numeric-(p->>'successful')::numeric/(p->>'total_attempts')::numeric)>0.000001 then return false; end if;
   allowed:=array['drill_name','successful','faults','total_attempts','success_rate'];
 elsif p_archetype='lap_interval' then
   if not (public._training_number(p,'lap_number',1,100) and public._training_number(p,'split_millis',1,86400000)
     and public._training_number(p,'distance_meters',1,100000)) then return false; end if;
   if p ? 'stroke_rate' and not public._training_number(p,'stroke_rate',0,300) then return false; end if;
   allowed:=array['lap_number','split_millis','distance_meters','stroke_rate'];
 elsif p_archetype='combat_rally' then
   if not (public._training_number(p,'rallies',1,10000) and public._training_number(p,'winners',0,10000)
     and public._training_number(p,'unforced_errors',0,10000)) then return false; end if;
   if (p->>'winners')::numeric+(p->>'unforced_errors')::numeric>(p->>'rallies')::numeric then return false; end if;
   allowed:=array['rallies','winners','unforced_errors'];
 elsif p_archetype='strength_set' then
   if jsonb_typeof(p->'exercise_name') is distinct from 'string' then return false; end if;
   if length(trim(p->>'exercise_name')) not between 1 and 120 then return false; end if;
   if not (public._training_number(p,'weight_kg',0,1000,false)
     and public._training_number(p,'reps',1,1000,true)) then return false; end if;
   if mod((p->>'weight_kg')::numeric*2,1)<>0 then return false; end if;
if p ? 'rpe' and not public._training_number(p,'rpe',1,10) then return false; end if;
if p ? 'good_lift' and jsonb_typeof(p->'good_lift') is distinct from 'boolean' then return false; end if;
   allowed:=array['exercise_name','weight_kg','reps','rpe','good_lift'];
 elsif p_archetype='routine_judge' then
   if jsonb_typeof(p->'routine_name') is distinct from 'string' then return false; end if;
   if length(trim(p->>'routine_name')) not between 1 and 120 then return false; end if;
   if not (public._training_number(p,'difficulty_score',0,100,false)
     and public._training_number(p,'execution_score',0,100,false)
     and public._training_number(p,'deductions',0,100,false)
     and public._training_number(p,'net_score',-100,200,false)) then return false; end if;
   if abs((p->>'net_score')::numeric-((p->>'difficulty_score')::numeric+(p->>'execution_score')::numeric-(p->>'deductions')::numeric))>0.000001 then return false; end if;
   allowed:=array['routine_name','difficulty_score','execution_score','deductions','net_score'];
 elsif p_archetype='mind_tactical' then
   if jsonb_typeof(p->'task_name') is distinct from 'string' then return false; end if;
   if length(trim(p->>'task_name')) not between 1 and 120 then return false; end if;
   if not (public._training_number(p,'solved_count',0,10000,true)
     and public._training_number(p,'failed_count',0,10000,true)
     and public._training_number(p,'duration_seconds',1,86400,true)
     and public._training_number(p,'accuracy_rate',0,1,false)) then return false; end if;
   if abs((p->>'accuracy_rate')::numeric-case when (p->>'solved_count')::numeric+(p->>'failed_count')::numeric=0 then 0 else (p->>'solved_count')::numeric/((p->>'solved_count')::numeric+(p->>'failed_count')::numeric) end)>0.000001 then return false; end if;
   allowed:=array['task_name','solved_count','failed_count','duration_seconds','accuracy_rate'];
 else return false;
 end if;
 for k in select jsonb_object_keys(p) loop
   if not (k=any(allowed)) then return false; end if;
 end loop;
 return true;
end;
$fn$;


with profiles(sport_code,archetype) as (values
 ('aticilik-avcilik','target_score'),
 ('geleneksel-okculuk','target_score'),
 ('okculuk','target_score'),
 ('bedensel-engelliler','strength_set'),
 ('halter','strength_set'),
 ('vucut-gelistirme-fitness','strength_set'),
 ('cimnastik','routine_judge'),
 ('dans-sporlari','routine_judge'),
 ('halk-oyunlari','routine_judge'),
 ('buz-pateni','routine_judge'),
 ('binicilik','routine_judge'),
 ('kaykay','routine_judge'),
 ('satranc','mind_tactical'),
 ('bric','mind_tactical'),
 ('e-spor','mind_tactical'),
 ('izcilik','mind_tactical'),
 ('dagcilik','mind_tactical'),
 ('hava-sporlari','mind_tactical'),
 ('atletizm','lap_interval'),
 ('bisiklet','lap_interval'),
 ('kano','lap_interval'),
 ('kayak','lap_interval'),
 ('kizak','lap_interval'),
 ('kurek','lap_interval'),
 ('motosiklet','lap_interval'),
 ('oryantiring','lap_interval'),
 ('otomobil-sporlari','lap_interval'),
 ('rafting','lap_interval'),
 ('sualti-sporlari','lap_interval'),
 ('triatlon','lap_interval'),
 ('yelken','lap_interval'),
 ('yuzme','lap_interval'),
 ('boks','combat_rally'),
 ('eskrim','combat_rally'),
 ('gures','combat_rally'),
 ('judo','combat_rally'),
 ('karate','combat_rally'),
 ('kick-boks','combat_rally'),
 ('muaythai','combat_rally'),
 ('taekwondo','combat_rally'),
 ('wushu-kung-fu','combat_rally'),
 ('badminton','combat_rally'),
 ('masa-tenisi','combat_rally'),
 ('tenis','combat_rally'),
 ('basketbol','attempt_drill'),
 ('bilardo','attempt_drill'),
 ('bocce-bowling-dart','attempt_drill'),
 ('buz-hokeyi','attempt_drill'),
 ('curling','attempt_drill'),
 ('futbol','attempt_drill'),
 ('golf','attempt_drill'),
 ('gorme-engelliler','attempt_drill'),
 ('hentbol','attempt_drill'),
 ('hokey','attempt_drill'),
 ('isitme-engelliler','attempt_drill'),
 ('modern-pentatlon','attempt_drill'),
 ('ozel-sporcular','attempt_drill'),
 ('ragbi','attempt_drill'),
 ('su-topu','attempt_drill'),
 ('voleybol','attempt_drill')
), variants(label,mode,sets) as (values
 ('Temel Teknik Çalışma','technique',3),
 ('Performans & Simülasyon','simulation',5)
)
insert into public.training_protocols(id,club_id,sport_code,name,description,config,published)
select md5('swansport/0120/'||p.sport_code||'/'||v.mode)::uuid,
 null,p.sport_code,s.name||' · '||v.label,
 'Genel antrenman şablonu; resmi müsabaka protokolü değildir.',
 jsonb_build_object('archetype',p.archetype,'set_count',v.sets,'units_per_set',20,
 'prep_seconds',10,'shoot_seconds',120,'collect_seconds',case when p.archetype='target_score' then 60 else 0 end,
 'rest_seconds',30,'max_unit_score',10,'entry_mode','flexible','mode',v.mode),true
from profiles p join public.sports s on s.code=p.sport_code cross join variants v
where not exists(select 1 from public.training_protocols t
 where t.id=md5('swansport/0120/'||p.sport_code||'/'||v.mode)::uuid);

revoke all on function public.valid_training_config(jsonb) from public, anon;
grant execute on function public.valid_training_config(jsonb) to authenticated;
revoke all on function public.valid_drill_metric(text,jsonb) from public, anon, authenticated;

-- Federation registrations deliberately have no client SELECT privilege.
-- Return only sport codes for an active member's own active club, not the registry.
create or replace function public.my_training_club_sports(p_club_id uuid)
returns table(sport_code text)
language plpgsql stable security definer set search_path = public as $fn$
begin
 if auth.uid() is null or not exists (
   select 1 from public.club_memberships m join public.clubs c on c.id=m.club_id
   where m.club_id=p_club_id and m.profile_id=auth.uid() and m.status='active' and c.status='active'
 ) then raise exception 'Aktif kulüp üyeliği gerekli'; end if;
 return query
 select c.sport_code from public.clubs c where c.id=p_club_id and c.sport_code is not null
 union
 select r.sport_code from public.club_sport_registrations r where r.club_id=p_club_id
 union
 select t.sport_code from public.teams t where t.club_id=p_club_id and t.sport_code is not null;
end;
$fn$;
revoke all on function public.my_training_club_sports(uuid) from public, anon, authenticated;
grant execute on function public.my_training_club_sports(uuid) to authenticated;

insert into public.faq_entries(question,answer,category,audience,feature,route,sort_order)
select 'Çok branşlı antrenmanda ölçüm ve branş filtresi nasıl çalışır?',
 'Tek branş otomatik seçilir; birden çok branşta çubuktan seçim yapabilir veya Tüm Branşlar aramasını kullanabilirsin. Bu seçim yalnız filtreleme yapar, yeni yetki vermez. Kuvvet setinde hareket, yarım kilogram adımlı ağırlık, tekrar ve isteğe bağlı RPE girilir. Jüri serisinde net puan zorluk ve uygulama toplamından kesintiler çıkarılarak hesaplanır. Zihinsel çalışmada çözülen, başarısız ve süre kaydedilir; deneme yoksa oran sıfırdır. Gönderilmemiş taslaklar bellektedir; uygulamayı kapatmadan kaydet. Bu şablonlar resmi müsabaka puanlama kuralları değildir.',
 'Antrenman','everyone','sport_training_sessions','/antrenman-sablonlari',140
where not exists(select 1 from public.faq_entries where question='Çok branşlı antrenmanda ölçüm ve branş filtresi nasıl çalışır?');
