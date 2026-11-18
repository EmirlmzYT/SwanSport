set local lock_timeout = '15s';

-- A coach records a simple set total for one explicitly selected participant.
-- Athlete self-entry remains on submit_set_score; this narrow RPC does not
-- broaden direct table writes or infer an athlete from client state.
create or replace function public.submit_coach_set_score(
  p_session uuid,
  p_athlete uuid,
  p_set_no int,
  p_total numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_session public.training_sessions%rowtype;
  v_config jsonb;
  v_units int;
  v_max numeric;
  v_set_id uuid;
begin
  select * into v_session
    from public.training_sessions
   where id = p_session
   for update;

  if not found then
    raise exception 'Oturum bulunamadı';
  end if;
  if v_session.kind <> 'club' or v_session.status not in ('live', 'review') then
    raise exception 'Kulüp oturumu ölçüme açık değil';
  end if;
  if not public.is_club_staff(v_session.club_id) then
    raise exception 'Kulüp personeli yetkisi gerekli' using errcode = '42501';
  end if;
  if not exists (
    select 1
      from public.training_session_participants participant
     where participant.session_id = p_session
       and participant.athlete_id = p_athlete
       and participant.left_at is null
  ) then
    raise exception 'Sporcu bu oturumun aktif katılımcısı değil';
  end if;

  select protocol.config into v_config
    from public.training_protocols protocol
   where protocol.id = v_session.protocol_id;
  v_units := (v_config->>'units_per_set')::numeric::int;
  v_max := (v_config->>'max_unit_score')::numeric;

  if coalesce(v_config->>'archetype', 'target_score') <> 'target_score'
     or v_config->>'entry_mode' = 'detailed' then
    raise exception 'Bu protokol ayrıntılı ölçüm modeli gerektiriyor';
  end if;
  if p_set_no is null
     or p_set_no < 1
     or p_set_no > (v_config->>'set_count')::numeric::int then
    raise exception 'Set numarası protokol dışında';
  end if;
  if p_total is null or p_total < 0 or p_total > v_units * v_max then
    raise exception 'Set toplamı protokol dışında';
  end if;

  insert into public.training_sets
    (session_id, athlete_id, set_no, total_score, completed_at, metric_payload)
  values
    (p_session, p_athlete, p_set_no, p_total, now(), '{}'::jsonb)
  on conflict (session_id, athlete_id, set_no) do update
    set total_score = excluded.total_score,
        completed_at = now(),
        metric_payload = excluded.metric_payload
  where training_sets.locked_at is null
  returning id into v_set_id;

  if v_set_id is null then
    raise exception 'Bu set onaylanmış, düzeltilemez';
  end if;

  delete from public.training_set_entries where set_id = v_set_id;
  return jsonb_build_object('set_id', v_set_id, 'total', p_total);
end;
$fn$;

revoke all on function public.submit_coach_set_score(uuid, uuid, int, numeric)
  from public, anon, authenticated;
grant execute on function public.submit_coach_set_score(uuid, uuid, int, numeric)
  to authenticated;
