drop policy if exists "training_shared_feedback_read" on public.training_shared_feedback;
create policy "training_shared_feedback_read"
on public.training_shared_feedback for select to authenticated
using (
  public.is_athlete_self(athlete_id)
  or public.is_guardian_of(athlete_id)
  or public.can_manage_training_session(session_id)
);

create or replace function public.training_progress(
  p_athlete uuid,
  p_from date,
  p_to date
)
returns table (
  session_id uuid,
  set_no int,
  sport_code text,
  source_kind text,
  club_id uuid,
  club_name text,
  started_at timestamptz,
  archetype text,
  work_name text,
  comparison_key text,
  primary_value numeric,
  unit text,
  shared_feedback text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if p_athlete is null or p_from is null or p_to is null
     or p_to < p_from or p_to - p_from > 365 then
    raise exception 'Geçersiz gelişim dönemi';
  end if;

  return query
  select s.id,
         t.set_no,
         pr.sport_code,
         s.kind,
         s.club_id,
         c.name,
         s.started_at,
         coalesce(pr.config->>'archetype', 'target_score') as archetype,
         case coalesce(pr.config->>'archetype', 'target_score')
           when 'attempt_drill' then t.metric_payload->>'drill_name'
           when 'lap_interval' then (t.metric_payload->>'distance_meters') || ' m'
           when 'strength_set' then t.metric_payload->>'exercise_name'
           when 'routine_judge' then t.metric_payload->>'routine_name'
           when 'mind_tactical' then t.metric_payload->>'task_name'
           else pr.name
         end as work_name,
         concat_ws(':',
           pr.sport_code,
           s.kind,
           coalesce(s.club_id::text, 'personal'),
           coalesce(pr.config->>'archetype', 'target_score'),
           case coalesce(pr.config->>'archetype', 'target_score')
             when 'attempt_drill' then t.metric_payload->>'drill_name'
             when 'lap_interval' then t.metric_payload->>'distance_meters'
             when 'strength_set' then t.metric_payload->>'exercise_name'
             when 'routine_judge' then t.metric_payload->>'routine_name'
             when 'mind_tactical' then t.metric_payload->>'task_name'
             else 'score'
           end
         ) as comparison_key,
         case coalesce(pr.config->>'archetype', 'target_score')
           when 'target_score' then t.total_score
           when 'attempt_drill' then (t.metric_payload->>'success_rate')::numeric * 100
           when 'lap_interval' then (t.metric_payload->>'split_millis')::numeric
           when 'combat_rally' then
             case when (t.metric_payload->>'rallies')::numeric = 0 then null
             else (t.metric_payload->>'winners')::numeric * 100
                  / (t.metric_payload->>'rallies')::numeric end
           when 'strength_set' then (t.metric_payload->>'weight_kg')::numeric
           when 'routine_judge' then (t.metric_payload->>'net_score')::numeric
           when 'mind_tactical' then (t.metric_payload->>'accuracy_rate')::numeric * 100
           else null
         end as primary_value,
         case coalesce(pr.config->>'archetype', 'target_score')
           when 'target_score' then 'puan'
           when 'attempt_drill' then '%'
           when 'lap_interval' then 'ms'
           when 'combat_rally' then '% winner'
           when 'strength_set' then 'kg'
           when 'routine_judge' then 'puan'
           when 'mind_tactical' then '%'
           else ''
         end as unit,
         sf.feedback
    from public.training_sets t
    join public.training_sessions s on s.id = t.session_id
    join public.training_protocols pr on pr.id = s.protocol_id
    left join public.clubs c on c.id = s.club_id
    left join public.training_shared_feedback sf
      on sf.session_id = s.id and sf.athlete_id = t.athlete_id
   where t.athlete_id = p_athlete
     and s.started_at >= p_from::timestamptz
     and s.started_at < (p_to + 1)::timestamptz
     and t.metric_payload <> '{}'::jsonb
     and (
       public.is_athlete_self(p_athlete)
       or public.can_manage_training_session(s.id)
       or (
         s.kind = 'club'
         and public.is_guardian_of(p_athlete)
         and sf.session_id is not null
       )
     )
   order by s.started_at desc, t.set_no desc;
end;
$fn$;

revoke execute on function public.training_progress(uuid, date, date)
  from public, anon, authenticated;
grant execute on function public.training_progress(uuid, date, date)
  to authenticated;
