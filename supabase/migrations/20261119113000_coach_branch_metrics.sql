set local lock_timeout = '15s';

-- Coach entry uses the same validated branch payload as athlete self-entry.
-- The athlete is explicit and server-authorized; no client-side selection is
-- trusted as proof of membership or participation.
create or replace function public.submit_coach_set_metric(
  p_session uuid,
  p_athlete uuid,
  p_set_no int,
  p_total numeric default null,
  p_metric_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  s public.training_sessions%rowtype;
  cfg jsonb;
  archetype text;
  mode text;
  units int;
  max_score numeric;
  entries jsonb;
  stored_total numeric;
  unit_count int;
  v_set_id uuid;
begin
  select * into s from public.training_sessions where id=p_session for update;
  if not found then raise exception 'Oturum bulunamadı'; end if;
  if s.kind<>'club' or s.status not in ('live','review') then
    raise exception 'Kulüp oturumu ölçüme açık değil';
  end if;
  if not public.is_club_staff(s.club_id) then
    raise exception 'Kulüp personeli yetkisi gerekli' using errcode='42501';
  end if;
  if not exists(select 1 from public.training_session_participants p
    where p.session_id=p_session and p.athlete_id=p_athlete and p.left_at is null) then
    raise exception 'Sporcu bu oturumun aktif katılımcısı değil';
  end if;

  select config into cfg from public.training_protocols where id=s.protocol_id;
  archetype:=coalesce(cfg->>'archetype','target_score');
  mode:=cfg->>'entry_mode';
  units:=(cfg->>'units_per_set')::numeric::int;
  max_score:=(cfg->>'max_unit_score')::numeric;
  if p_set_no is null or p_set_no<1 or p_set_no>(cfg->>'set_count')::numeric::int then
    raise exception 'Set numarası protokol dışında';
  end if;
  if not public.valid_drill_metric(archetype,p_metric_payload) then
    raise exception 'Geçersiz drill metriği';
  end if;

  if archetype='target_score' and p_metric_payload<>'{}'::jsonb then
    if p_total is not null then raise exception 'Hedef metriği ile ikinci skor gönderilemez'; end if;
    entries:=(select jsonb_agg(case when e.value='X' then 10 when e.value='M' then 0 else e.value::numeric end)
      from jsonb_array_elements_text(p_metric_payload->'marks') e);
    if jsonb_array_length(entries)>units then raise exception 'Tekrar sayısı protokol dışında'; end if;
    if exists(select 1 from jsonb_array_elements(entries) e where e.value::text::numeric>max_score) then
      raise exception 'Geçersiz hedef puanı';
    end if;
    select sum(e.value::text::numeric),count(*) into stored_total,unit_count
      from jsonb_array_elements(entries) e;
  elsif archetype<>'target_score' then
    if p_total is not null or p_metric_payload='{}'::jsonb then
      raise exception 'Drill sonucu yalnız metric_payload ile yazılır';
    end if;
    stored_total:=case archetype
      when 'attempt_drill' then (p_metric_payload->>'successful')::numeric
      when 'combat_rally' then (p_metric_payload->>'winners')::numeric
      else null end;
    unit_count:=case archetype
      when 'attempt_drill' then (p_metric_payload->>'total_attempts')::numeric::int
      when 'combat_rally' then (p_metric_payload->>'rallies')::numeric::int
      else 1 end;
    if unit_count>units then raise exception 'Tekrar sayısı protokol dışında'; end if;
  else
    if mode<>'simple' or p_total is null or p_total<0 or p_total>units*max_score then
      raise exception 'Set toplamı protokol dışında';
    end if;
    stored_total:=p_total;
    unit_count:=units;
  end if;

  insert into public.training_sets
    (session_id,athlete_id,set_no,total_score,unit_count,completed_at,metric_payload)
  values(p_session,p_athlete,p_set_no,stored_total,unit_count,now(),p_metric_payload)
  on conflict(session_id,athlete_id,set_no) do update set
    total_score=excluded.total_score,unit_count=excluded.unit_count,
    completed_at=now(),metric_payload=excluded.metric_payload
  where training_sets.locked_at is null returning id into v_set_id;
  if v_set_id is null then raise exception 'Bu set onaylanmış, düzeltilemez'; end if;

  delete from public.training_set_entries where training_set_entries.set_id=v_set_id;
  if archetype='target_score' and mode='detailed' then
    insert into public.training_set_entries(set_id,seq,score)
      select v_set_id,e.ordinality,(e.value)::text::numeric
      from jsonb_array_elements(entries) with ordinality e(value,ordinality);
  end if;
  return jsonb_build_object('set_id',v_set_id,'total',stored_total,'metric_payload',p_metric_payload);
end;
$fn$;

revoke all on function public.submit_coach_set_metric(uuid,uuid,int,numeric,jsonb)
  from public,anon,authenticated;
grant execute on function public.submit_coach_set_metric(uuid,uuid,int,numeric,jsonb)
  to authenticated;
