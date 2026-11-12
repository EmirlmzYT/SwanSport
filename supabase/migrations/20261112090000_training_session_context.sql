set local lock_timeout = '15s';

-- The session owns the historical sport/source/club identity. Never infer a
-- legacy row from the athlete's current profile, membership, or main sport.
create or replace function public.my_training_history_v2(p_limit int default 30)
returns table (
  session_id    uuid,
  kind          text,
  protocol_name text,
  sport_code    text,
  club_id       uuid,
  club_name     text,
  coach_name    text,
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
         s.club_id,
         c.name,
         nullif(trim(created.full_name), ''),
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
    join public.clubs c on c.id = s.club_id
    join public.athletes a on a.profile_id = auth.uid()
    left join public.profiles created on created.id = s.created_by
    left join lateral (
      select count(*) filter (
               where t.total_score is not null
                  or t.metric_payload <> '{}'::jsonb)::int as done,
             sum(t.total_score) as total,
             max(t.total_score) as best,
             avg(t.total_score) as avg_set
        from public.training_sets t
       where t.session_id = s.id and t.athlete_id = a.id) agg on true
    left join public.training_self_assessments sa
           on sa.session_id = s.id and sa.athlete_id = a.id
   where (s.kind = 'personal' and s.athlete_id = a.id)
      or (s.kind = 'club' and exists (
            select 1
              from public.training_session_participants participant
             where participant.session_id = s.id
               and participant.athlete_id = a.id))
   order by s.started_at desc
   limit greatest(coalesce(p_limit, 30), 1);
$fn$;

revoke all on function public.my_training_history_v2(int)
  from public, anon, authenticated;
grant execute on function public.my_training_history_v2(int) to authenticated;
