set local lock_timeout = '15s';
-- 0105: Existing immutable protocol config and training_sets are the only stores.
-- No training_sessions.config or training_set_scores duplicate is introduced.

create or replace function public._training_number(p jsonb, k text, lo numeric, hi numeric, whole boolean default true)
returns boolean language sql immutable set search_path = public as $fn$
 select coalesce(case when jsonb_typeof(p->k) = 'number' then
   (p->>k)::numeric between lo and hi and (not whole or trunc((p->>k)::numeric)=(p->>k)::numeric)
 else false end,false);
$fn$;

create or replace function public.valid_training_config(p jsonb)
returns boolean language sql immutable set search_path = public as $fn$
 select coalesce(jsonb_typeof(p)='object'
   and coalesce(p->>'archetype','target_score') in ('target_score','attempt_drill','lap_interval','combat_rally')
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
 else return false;
 end if;
 for k in select jsonb_object_keys(p) loop
   if not (k=any(allowed)) then return false; end if;
 end loop;
 return true;
end;
$fn$;

alter table public.training_sets add column if not exists metric_payload jsonb not null default '{}'::jsonb;
alter table public.training_sets alter column metric_payload set default '{}'::jsonb;
update public.training_sets set metric_payload='{}'::jsonb where metric_payload is null;
alter table public.training_sets alter column metric_payload set not null;
alter table public.training_sets drop constraint if exists training_metric_object;
alter table public.training_sets add constraint training_metric_object check(coalesce(jsonb_typeof(metric_payload)='object',false));
alter table public.training_sessions drop constraint if exists training_session_phase_valid;
alter table public.training_sessions add constraint training_session_phase_valid check(current_phase in
 ('prep','shoot','collect','score','rest','done','active_drill','lap_active','rest_interval'));

create or replace function public.training_next_phase(p_phase text,p_set int,p_config jsonb)
returns jsonb language plpgsql immutable set search_path = public as $fn$
declare a text:=coalesce(p_config->>'archetype','target_score'); ph text; n int:=p_set;
begin
 if not public.valid_training_config(p_config) then raise exception 'Geçersiz antrenman yapılandırması'; end if;
 if a<>'target_score' then
   if p_phase='done' then ph:='done';
   elsif p_phase='prep' then ph:=case when a='lap_interval' then 'lap_active' else 'active_drill' end;
   elsif p_phase=(case when a='lap_interval' then 'rest_interval' else 'rest' end) then ph:='prep';n:=p_set+1;
   elsif p_phase=(case when a='lap_interval' then 'lap_active' else 'active_drill' end) then
     if p_set >= (p_config->>'set_count')::numeric::int then ph:='done';
     elsif (p_config->>'rest_seconds')::numeric::int>0 then ph:=case when a='lap_interval' then 'rest_interval' else 'rest' end;
     else ph:='prep';n:=p_set+1; end if;
   else raise exception 'Arketip için geçersiz aşama'; end if;
   return jsonb_build_object('phase',ph,'set_no',n);
 end if;
 if p_phase not in ('prep','shoot','collect','score','rest','done') then raise exception 'Geçersiz hedef aşaması'; end if;
 return (with c as (
    select coalesce((p_config->>'set_count')::numeric::int, 1)       as set_count,
           coalesce((p_config->>'collect_seconds')::numeric::int, 0) as collect_s,
           coalesce((p_config->>'rest_seconds')::numeric::int, 0)    as rest_s
  )
  select case p_phase
    when 'prep' then jsonb_build_object('phase', 'shoot', 'set_no', p_set)
    when 'shoot' then
      case when c.collect_s > 0
        then jsonb_build_object('phase', 'collect', 'set_no', p_set)
        else jsonb_build_object('phase', 'score', 'set_no', p_set)
      end
    when 'collect' then jsonb_build_object('phase', 'score', 'set_no', p_set)
    when 'score' then
      case
        when p_set >= c.set_count
          then jsonb_build_object('phase', 'done', 'set_no', p_set)
        when c.rest_s > 0
          then jsonb_build_object('phase', 'rest', 'set_no', p_set)
        else jsonb_build_object('phase', 'prep', 'set_no', p_set + 1)
      end
    when 'rest' then jsonb_build_object('phase', 'prep', 'set_no', p_set + 1)
    else jsonb_build_object('phase', 'done', 'set_no', p_set)
  end
  from c);
end;
$fn$;
create or replace function public.training_phase_seconds(
  p_phase text, p_config jsonb)
returns int
language sql
immutable
as $fn$
  select case p_phase
    when 'prep'    then coalesce((p_config->>'prep_seconds')::numeric::int, 0)
    when 'active_drill' then coalesce((p_config->>'shoot_seconds')::numeric::int, 0)
    when 'lap_active' then coalesce((p_config->>'shoot_seconds')::numeric::int, 0)
    when 'rest_interval' then coalesce((p_config->>'rest_seconds')::numeric::int, 0)
    when 'shoot'   then coalesce((p_config->>'shoot_seconds')::numeric::int, 0)
    when 'collect' then coalesce((p_config->>'collect_seconds')::numeric::int, 0)
    when 'rest'    then coalesce((p_config->>'rest_seconds')::numeric::int, 0)
    else null
  end;
$fn$;
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
      or coalesce(v_cfg->>'archetype','target_score') in ('attempt_drill','combat_rally') and p_phase in ('shoot','collect','score','lap_active','rest_interval')
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

drop function if exists public.submit_set_score(uuid,int,numeric,jsonb);
create or replace function public.submit_set_score(
  p_session uuid,
  p_set_no int,
  p_total numeric default null,
  p_entries jsonb default null,
  p_metric_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare v_s       public.training_sessions%rowtype;
        v_cfg     jsonb;
        v_athlete uuid;
        v_mode    text;
        v_units   int;
        v_max     numeric;
        v_total   numeric;
        v_count   int;
        v_set_id uuid;
        v_archetype text;
begin
  select * into v_s from public.training_sessions where id = p_session for update;
  if not found then
    raise exception 'Oturum bulunamadı';
  end if;
  if v_s.status not in ('live', 'review') then
    raise exception 'Oturum kapanmış';
  end if;

  if v_s.kind = 'personal' then
    if not public.is_athlete_self(v_s.athlete_id) then
      raise exception 'Bu oturum senin değil';
    end if;
    v_athlete := v_s.athlete_id;
  else
    select a.id into v_athlete from public.athletes a
     where a.profile_id = auth.uid() and a.club_id = v_s.club_id
       and a.status = 'active'
     limit 1;
    if v_athlete is null then
      raise exception 'Bu oturuma kayıtlı değilsin';
    end if;
    if not exists (select 1 from public.training_session_participants p
                    where p.session_id = p_session and p.athlete_id = v_athlete and p.left_at is null) then
      raise exception 'Önce oturuma katılmalısın';
    end if;
  end if;

  select config into v_cfg from public.training_protocols where id = v_s.protocol_id;
  v_mode  := v_cfg->>'entry_mode';
  v_units := (v_cfg->>'units_per_set')::numeric::int;
  v_max   := (v_cfg->>'max_unit_score')::numeric;

  if p_set_no is null or p_set_no < 1 or p_set_no > (v_cfg->>'set_count')::numeric::int then
    raise exception 'Set numarası protokol dışında';
  end if;

  v_archetype:=coalesce(v_cfg->>'archetype','target_score');
  if not public.valid_drill_metric(v_archetype,p_metric_payload) then raise exception 'Geçersiz drill metriği'; end if;
  if v_archetype='target_score' and p_metric_payload<>'{}'::jsonb then
    if p_entries is not null or p_total is not null then raise exception 'Hedef metriği ile ikinci skor gönderilemez'; end if;
    p_entries:=(select jsonb_agg(case when e.value='X' then 10 when e.value='M' then 0 else e.value::numeric end)
      from jsonb_array_elements_text(p_metric_payload->'marks') e);
    if v_mode='simple' then
      if jsonb_array_length(p_entries)>v_units then raise exception 'Tekrar sayısı protokol dışında'; end if;
      if exists(select 1 from jsonb_array_elements(p_entries) e where e.value::text::numeric>v_max) then raise exception 'Geçersiz hedef puanı'; end if;
      select sum(e.value::text::numeric) into p_total from jsonb_array_elements(p_entries) e;
      p_entries:=null;
    end if;
  end if;
  if v_archetype<>'target_score' then
    if p_entries is not null or p_total is not null then raise exception 'Drill sonucu yalnız metric_payload ile yazılır'; end if;
    v_total:=case v_archetype when 'attempt_drill' then (p_metric_payload->>'successful')::numeric
       when 'combat_rally' then (p_metric_payload->>'winners')::numeric else null end;
    v_count:=case v_archetype when 'attempt_drill' then (p_metric_payload->>'total_attempts')::numeric::int
       when 'combat_rally' then (p_metric_payload->>'rallies')::numeric::int else 1 end;
    if v_count>v_units then raise exception 'Tekrar sayısı protokol dışında'; end if;
  else
  if v_mode = 'simple' and p_entries is not null then
    raise exception 'Bu oturumda yalnızca set toplamı giriliyor';
  end if;
  if v_mode = 'detailed' and p_entries is null then
    raise exception 'Bu oturumda her atışın puanı tek tek giriliyor';
  end if;

  if p_entries is not null then
    if jsonb_typeof(p_entries) <> 'array' then
      raise exception 'Atış listesi dizi olmalı';
    end if;
    if jsonb_array_length(p_entries) > v_units then
      raise exception 'Protokolde set başına en fazla % atış var', v_units;
    end if;
    if exists (
      select 1 from jsonb_array_elements(p_entries) e
       where jsonb_typeof(e.value) not in ('number', 'null')
          or case when jsonb_typeof(e.value) = 'number' then
              (e.value)::text::numeric < 0 or (e.value)::text::numeric > v_max else false end
    ) then
      raise exception 'Atış puanı 0 ile % arasında olmalı', v_max;
    end if;

    select sum((e.value)::text::numeric), count(*)
      into v_total, v_count
      from jsonb_array_elements(p_entries) e
     where jsonb_typeof(e.value) = 'number';
  else
    v_total := p_total;
    v_count := case when p_metric_payload ? 'marks' then jsonb_array_length(p_metric_payload->'marks') else null end;
    if v_total is not null
       and (v_total < 0 or v_total > v_units * v_max) then
      raise exception 'Set toplamı 0 ile % arasında olmalı', v_units * v_max;
    end if;
  end if;

  end if;

  insert into public.training_sets
    (session_id, athlete_id, set_no, total_score, unit_count, completed_at, metric_payload)
  values (p_session, v_athlete, p_set_no, v_total, v_count, now(), p_metric_payload)
  on conflict (session_id, athlete_id, set_no) do update
    set total_score  = excluded.total_score,
        unit_count   = excluded.unit_count,
        completed_at = now(),
        metric_payload = excluded.metric_payload
  where training_sets.locked_at is null
  returning id into v_set_id;

  if v_set_id is null then
    raise exception 'Bu set antrenör tarafından onaylanmış, düzeltilemez';
  end if;

  delete from public.training_set_entries where set_id = v_set_id;
  if p_entries is not null then
    insert into public.training_set_entries (set_id, seq, score)
    select v_set_id, e.ord,
           case when jsonb_typeof(e.value) = 'number'
                then (e.value)::text::numeric end
      from jsonb_array_elements(p_entries) with ordinality as e(value, ord);
  end if;

  return jsonb_build_object('set_id', v_set_id, 'total', v_total,
                            'units', v_count);
end;
$fn$;
create or replace function public.lock_session_results(p_session uuid)
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare v_n int;
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumu onaylama yetkin yok';
  end if;

  perform 1 from public.training_sessions where id=p_session for update;

  update public.training_sets
     set locked_at = now(), locked_by = auth.uid()
   where session_id = p_session and locked_at is null;
  get diagnostics v_n = row_count;

  update public.training_sessions
     set status = 'completed',
         ended_at = coalesce(ended_at, now()),
         join_code = null
   where id = p_session;

  insert into public.training_session_events
    (session_id, actor_id, action, new_value)
  values (p_session, auth.uid(), 'lock',
          jsonb_build_object('locked_sets', v_n));

  return v_n;
end;
$fn$;
drop function if exists public.correct_locked_set(uuid,numeric,text,jsonb);
create or replace function public.correct_locked_set(
  p_set uuid,
  p_total numeric,
  p_reason text,
  p_entries jsonb default null, p_metric_payload jsonb default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare v_set public.training_sets%rowtype;
        v_old jsonb; v_cfg jsonb; v_a text; v_count int;
begin
  select * into v_set from public.training_sets where id = p_set;
  if not found then
    raise exception 'Set bulunamadı';
  end if;
  if not public.can_manage_training_session(v_set.session_id) then
    raise exception 'Bu sonucu düzeltme yetkin yok';
  end if;
  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'Düzeltme gerekçesi zorunlu';
  end if;

  perform 1 from public.training_sessions where id=v_set.session_id for update;
  select * into v_set from public.training_sets where id=p_set for update;
  select pr.config into v_cfg from public.training_sessions s join public.training_protocols pr on pr.id=s.protocol_id
    where s.id=v_set.session_id;
  v_a:=coalesce(v_cfg->>'archetype','target_score');
  if p_metric_payload is null and v_set.metric_payload<>'{}'::jsonb then
    raise exception 'Metrik sonuçlar için düzeltilmiş metric_payload gerekli'; end if;
  if p_metric_payload is not null then
    if not public.valid_drill_metric(v_a,p_metric_payload) or p_metric_payload='{}'::jsonb then raise exception 'Geçersiz drill metriği'; end if;
    if p_total is not null or p_entries is not null then raise exception 'Metrikle ikinci skor gönderilemez'; end if;
    if v_a='target_score' then
      p_entries:=(select jsonb_agg(case when e.value='X' then 10 when e.value='M' then 0 else e.value::numeric end)
        from jsonb_array_elements_text(p_metric_payload->'marks') e);
      select sum(e.value::text::numeric),count(*)::int into p_total,v_count from jsonb_array_elements(p_entries) e;
    else
      p_total:=case v_a when 'attempt_drill' then (p_metric_payload->>'successful')::numeric
        when 'combat_rally' then (p_metric_payload->>'winners')::numeric else null end;
      v_count:=case v_a when 'attempt_drill' then (p_metric_payload->>'total_attempts')::numeric::int
        when 'combat_rally' then (p_metric_payload->>'rallies')::numeric::int else 1 end;
    end if;
    if v_count>(v_cfg->>'units_per_set')::numeric::int then raise exception 'Tekrar sayısı protokol dışında'; end if;
  elsif v_a<>'target_score' then raise exception 'Drill metriği zorunlu';
  end if;
  if p_entries is not null then
    if jsonb_typeof(p_entries) is distinct from 'array' then raise exception 'Atış listesi dizi olmalı'; end if;
    if jsonb_array_length(p_entries)>(v_cfg->>'units_per_set')::numeric::int then raise exception 'Tekrar sayısı protokol dışında'; end if;
    if exists(select 1 from jsonb_array_elements(p_entries) e where
      case when jsonb_typeof(e.value)='number' then e.value::text::numeric < 0 or e.value::text::numeric >(v_cfg->>'max_unit_score')::numeric
      else jsonb_typeof(e.value)<>'null' end) then raise exception 'Geçersiz atış puanı'; end if;
    select sum(e.value::text::numeric) into p_total from jsonb_array_elements(p_entries) e where jsonb_typeof(e.value)='number';
  end if;
  if v_a='target_score' and p_total is not null and (p_total<0 or p_total>(v_cfg->>'units_per_set')::numeric::int*(v_cfg->>'max_unit_score')::numeric) then
    raise exception 'Geçersiz set toplamı'; end if;
  v_old := jsonb_build_object('metric_payload',v_set.metric_payload,

    'total', v_set.total_score, 'units', v_set.unit_count,
    'entries', (select jsonb_agg(e.score order by e.seq)
                  from public.training_set_entries e where e.set_id = p_set));

  update public.training_sets
     set total_score = p_total,
         metric_payload = coalesce(p_metric_payload,v_set.metric_payload),
         unit_count  = case
           when p_metric_payload is not null then v_count
           when p_entries is null then v_set.unit_count
           else (select count(*)::int from jsonb_array_elements(p_entries) e
                  where jsonb_typeof(e.value) = 'number')
         end
   where id = p_set;

  if p_entries is not null then
    delete from public.training_set_entries where set_id = p_set;
    insert into public.training_set_entries (set_id, seq, score)
    select p_set, e.ord,
           case when jsonb_typeof(e.value) = 'number'
                then (e.value)::text::numeric end
      from jsonb_array_elements(p_entries) with ordinality as e(value, ord);
  end if;

  insert into public.training_session_events
    (session_id, actor_id, action, reason, set_no, athlete_id,
     old_value, new_value)
  values (v_set.session_id, auth.uid(), 'correct', trim(p_reason),
          v_set.set_no, v_set.athlete_id, v_old,
          jsonb_build_object('total', p_total, 'entries', p_entries,'metric_payload',coalesce(p_metric_payload,v_set.metric_payload)));
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
           case when pr.config->>'archetype'='lap_interval' then 1 else (pr.config->>'units_per_set')::numeric::int end as units_per_set
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
         case when pr.config->>'archetype'='lap_interval' then null::numeric else agg.total end,
         round(agg.avg_all, 2),
         agg.units,
         parts.n * (pr.config->>'set_count')::numeric::int
                 * case when pr.config->>'archetype'='lap_interval' then 1 else (pr.config->>'units_per_set')::numeric::int end,
         pr.name,
         pr.version,
         (pr.config->>'set_count')::numeric::int,
         s.status
    from s, pr, parts, agg;
end;
$fn$;
create or replace function public.my_training_history(p_limit int default 30)
returns table (
  session_id    uuid,
  kind          text,
  protocol_name text,
  sport_code    text,
  started_at    timestamptz,
  status        text,
  sets_done     int,
  set_count     int,
  total_score   numeric,
  best_set      numeric,
  avg_set       numeric,
  rpe           int)
language sql
stable
security definer
set search_path = public
as $fn$
  select s.id,
         s.kind,
         pr.name,
         pr.sport_code,
         s.started_at,
         s.status,
         coalesce(agg.done, 0),
         (pr.config->>'set_count')::numeric::int,
         agg.total,
         agg.best,
         round(agg.avg_set, 2),
         sa.rpe
    from public.training_sessions s
    join public.training_protocols pr on pr.id = s.protocol_id
    join public.athletes a
      on a.profile_id = auth.uid()
     and a.club_id = s.club_id
    left join lateral (
      select count(*) filter (where t.total_score is not null or t.metric_payload <> '{}'::jsonb)::int as done,
             sum(t.total_score) as total,
             max(t.total_score) as best,
             avg(t.total_score) as avg_set
        from public.training_sets t
       where t.session_id = s.id and t.athlete_id = a.id) agg on true
    left join public.training_self_assessments sa
           on sa.session_id = s.id and sa.athlete_id = a.id
   where (s.kind = 'personal' and s.athlete_id = a.id)
      or (s.kind = 'club' and exists (
            select 1 from public.training_session_participants p
             where p.session_id = s.id and p.athlete_id = a.id))
   order by s.started_at desc
   limit greatest(coalesce(p_limit, 30), 1);
$fn$;

create or replace function public.submit_coach_drill_note(p_session uuid,p_athlete uuid,p_note text,p_tag text)
returns void language plpgsql security definer set search_path = public as $fn$
declare s public.training_sessions%rowtype;
begin
 select * into s from public.training_sessions where id=p_session for update;
 if not found or s.kind<>'club' or not coalesce(public.can_manage_training_session(p_session),false) then
   raise exception 'Bu oturuma antrenör notu yazma yetkin yok'; end if;
 if s.status not in ('live','review') then raise exception 'Oturum kapanmış'; end if;
 if p_note is null or length(trim(p_note)) not between 1 and 1000 or
    p_tag is null or length(trim(p_tag)) not between 1 and 40 then raise exception 'Not/etiket geçersiz'; end if;
 if not exists(select 1 from public.training_session_participants p join public.athletes a on a.id=p.athlete_id
   where p.session_id=p_session and p.athlete_id=p_athlete and p.left_at is null and a.club_id=s.club_id) then
   raise exception 'Sporcu bu oturumda değil'; end if;
 insert into public.training_session_events(session_id,actor_id,action,athlete_id,phase,set_no,new_value)
 values(p_session,auth.uid(),'drill_note',p_athlete,s.current_phase,s.current_set,
   jsonb_build_object('note',trim(p_note),'tag',trim(p_tag)));
end;
$fn$;
create or replace function public.my_live_training_session()
returns table (
  session_id    uuid,
  club_id       uuid,
  kind          text,
  protocol_name text,
  current_phase text,
  current_set   int,
  set_count     int,
  phase_ends_at timestamptz,
  paused        boolean,
  rhythm        text)
language sql
stable
security definer
set search_path = public
as $fn$
  select s.id, s.club_id, s.kind, pr.name, s.current_phase, s.current_set,
         (pr.config->>'set_count')::numeric::int, s.phase_ends_at,
         s.paused_at is not null, s.rhythm
    from public.training_sessions s
    join public.training_protocols pr on pr.id = s.protocol_id
    join public.athletes a
      on a.profile_id = auth.uid() and a.club_id = s.club_id
    join public.training_session_participants p
      on p.session_id = s.id and p.athlete_id = a.id
   where s.status = 'live'
   order by s.started_at desc
   limit 1;
$fn$;
revoke execute on function public._training_number(jsonb,text,numeric,numeric,boolean) from public, anon, authenticated;
grant execute on function public._training_number(jsonb,text,numeric,numeric,boolean) to authenticated;
revoke execute on function public.valid_training_config(jsonb) from public, anon, authenticated;
grant execute on function public.valid_training_config(jsonb) to authenticated;
revoke execute on function public.valid_drill_metric(text,jsonb) from public, anon, authenticated;
revoke execute on function public.training_next_phase(text,int,jsonb) from public, anon, authenticated;
revoke execute on function public.training_phase_seconds(text,jsonb) from public, anon, authenticated;
revoke execute on function public.advance_session_phase(uuid,text,text) from public, anon, authenticated;
grant execute on function public.advance_session_phase(uuid,text,text) to authenticated;
revoke execute on function public.submit_set_score(uuid,int,numeric,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.submit_set_score(uuid,int,numeric,jsonb,jsonb) to authenticated;
revoke execute on function public.correct_locked_set(uuid,numeric,text,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.correct_locked_set(uuid,numeric,text,jsonb,jsonb) to authenticated;
revoke execute on function public.lock_session_results(uuid) from public, anon, authenticated;
grant execute on function public.lock_session_results(uuid) to authenticated;
revoke execute on function public.session_summary(uuid) from public, anon, authenticated;
grant execute on function public.session_summary(uuid) to authenticated;
revoke execute on function public.session_overview(uuid) from public, anon, authenticated;
grant execute on function public.session_overview(uuid) to authenticated;
revoke execute on function public.my_training_history(int) from public, anon, authenticated;
grant execute on function public.my_training_history(int) to authenticated;
revoke execute on function public.my_live_training_session() from public, anon, authenticated;
grant execute on function public.my_live_training_session() to authenticated;
revoke execute on function public.submit_coach_drill_note(uuid,uuid,text,text) from public, anon, authenticated;
grant execute on function public.submit_coach_drill_note(uuid,uuid,text,text) to authenticated;
