-- Adults are named regardless of retained guardian consent/refusal records.
-- Keep the published 0097 migration immutable; apply this file in its own transaction.
set local lock_timeout = '15s';

drop function if exists public.public_program_result(uuid);
create function public.public_program_result(p_match uuid)
returns table(protocol jsonb)
language plpgsql stable security definer set search_path=public as $$
declare v_protocol jsonb; v_sport text; v_home_roster uuid; v_away_roster uuid;
 v_type text; v_entries jsonb;
begin
 select r.protocol,o.sport_code,r.home_roster_revision_id,r.away_roster_revision_id
 into v_protocol,v_sport,v_home_roster,v_away_roster
 from public.org_matches m join public.organizations o on o.id=m.org_id
 join public.org_result_revisions r on r.match_id=m.id and r.version=m.result_version
 where m.id=p_match and o.official and o.is_public and m.status='played' and m.result_version>0;
 if not found then return; end if;
 -- Fail closed for malformed historical data, even if written outside the normal RPC.
 if not public._valid_official_protocol(v_protocol) then return; end if;
 v_type:=v_protocol->>'type';
 if v_type='score' then
  return query select jsonb_build_object('type','score',
   'home',(v_protocol->>'home')::numeric,'away',(v_protocol->>'away')::numeric);
 elsif v_type='sets' then
  select jsonb_agg(jsonb_build_object('home',(e.item->>'home')::numeric,
   'away',(e.item->>'away')::numeric) order by e.ordinal) into v_entries
  from jsonb_array_elements(v_protocol->'sets') with ordinality e(item,ordinal);
  return query select jsonb_build_object('type','sets','sets',v_entries);
 elsif v_type in ('time','rank') then
  -- Only result entries, never the full roster. Never project any athlete UUID.
  select jsonb_agg(jsonb_build_object(
   'name',case
    when at.id is null or not exists(select 1 from public.athlete_sport_registrations reg
      where reg.athlete_id=at.id and reg.sport_code=v_sport) then 'sporcu'
    when (at.birth_date is null
      or at.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date)
     and (not exists(select 1 from public.athlete_publicity ap
       join public.guardians g on g.id=ap.guardian_id and g.athlete_id=ap.athlete_id
       where ap.athlete_id=at.id and g.profile_id is not null and ap.allowed)
      or exists(select 1 from public.athlete_publicity ap
       join public.guardians g on g.id=ap.guardian_id and g.athlete_id=ap.athlete_id
       where ap.athlete_id=at.id and g.profile_id is not null and not ap.allowed)) then 'sporcu'
    else trim(at.first_name||' '||at.last_name) end,
   'value',(e.item->>'value')::numeric,'placement',(e.item->>'placement')::int)
   order by e.ordinal) into v_entries
  from jsonb_array_elements(v_protocol->'entries') with ordinality e(item,ordinal)
  left join public.athletes at on at.id=(e.item->>'athlete_id')::uuid
   and exists(select 1 from public.org_roster_revisions roster
    where roster.id in(v_home_roster,v_away_roster) and at.id=any(roster.athlete_ids));
  return query select jsonb_build_object('type',v_type,'entries',coalesce(v_entries,'[]'::jsonb));
 end if;
end $$;
revoke all on function public.public_program_result(uuid) from public,anon,authenticated;
grant execute on function public.public_program_result(uuid) to anon,authenticated;
