set local lock_timeout = '15s';

-- A federation operator's reason is an internal audit note. It can mention
-- an appeal, discipline action, or a minor, so it must never become part of
-- an anonymous result projection. The public stream exposes only a fixed,
-- non-sensitive publication label.
create or replace function public._public_result_revision_label(p_version int)
returns text language sql immutable set search_path=public,pg_temp as $$
  select case when p_version > 1 then 'Resmi sonuç güncellendi'
              else 'Resmi sonuç tescil edildi' end
$$;
revoke all on function public._public_result_revision_label(int) from public, anon, authenticated;

create or replace function public._public_match_header(p_match uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare rec record; st jsonb; protocol jsonb; live boolean; stamp timestamptz:=clock_timestamp();
  hs int; aws int; elapsed int; anchor timestamptz; final_at timestamptz;
  rev_reason text;
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
    select r.recorded_at into final_at from public.org_result_revisions r
      where r.match_id=p_match and r.version=rec.result_version;
    rev_reason:=public._public_result_revision_label(rec.result_version);
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
    'result_version',case when rec.status='played' then coalesce(rec.result_version,0) else 0 end,
    'revision_reason',rev_reason,
    'sets',case when rec.status='played' then coalesce(protocol->'sets','[]'::jsonb)
      when rec.sport_code='tenis' and live then st->'sets' else '[]'::jsonb end,
    'period_home',case when rec.sport_code='tenis' and live then (st->>'period_home')::int else null end,
    'period_away',case when rec.sport_code='tenis' and live then (st->>'period_away')::int else null end);
end $$;

create or replace function public.public_match_result_revisions(p_match_id uuid)
returns table(id uuid, version int, reason text, recorded_at timestamptz, is_current boolean)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare rec record;
begin
  select m.id, m.result_version into rec
  from public.org_matches m join public.organizations o on o.id=m.org_id
  where m.id=p_match_id and o.official and o.is_public and m.status='played' and m.result_version>0;
  if not found then return; end if;
  return query
  select r.id,r.version,public._public_result_revision_label(r.version),r.recorded_at,
    (r.version=rec.result_version)
  from public.org_result_revisions r
  where r.match_id=p_match_id order by r.version desc;
end $$;
revoke all on function public.public_match_result_revisions(uuid) from public,anon,authenticated;
grant execute on function public.public_match_result_revisions(uuid) to anon,authenticated;
