-- Phase B: explicit publication, then allowlisted guest projections only.
-- Apply in its own transaction; do not bundle migrations into one transaction.
set local lock_timeout = '15s';

drop function if exists public.federation_publish_program(uuid,boolean);
create function public.federation_publish_program(p_org uuid,p_public boolean)
returns void language plpgsql security definer set search_path=public as $$
declare v_sport text; v_city text; v_previous boolean; v_appointment uuid;
begin
 if p_public is null then raise exception 'Yayın tercihi gerekli'; end if;
 select o.sport_code,o.city_code,o.is_public into v_sport,v_city,v_previous
 from public.organizations o where o.id=p_org and o.official for update;
 if not found then raise exception 'Resmi program yetkisi gerekli' using errcode='42501'; end if;
 v_appointment:=public._federation_require(v_sport,v_city,'program_publisher');
 update public.organizations set is_public=p_public,
 published_at=case when p_public then clock_timestamp() else null end where id=p_org;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail)
 values(auth.uid(),v_appointment,'program_publication',p_org,
 jsonb_build_object('previous_is_public',v_previous,'is_public',p_public));
end $$;
revoke all on function public.federation_publish_program(uuid,boolean) from public,anon,authenticated;
grant execute on function public.federation_publish_program(uuid,boolean) to authenticated;

-- No backfill: federation_create_program still inserts is_public=false.
drop function if exists public.public_sport_programs();
create function public.public_sport_programs()
returns table(id uuid,name text,sport_code text,city_code text,season_label text,starts_on date,ends_on date)
language sql stable security definer set search_path=public as $$
 select o.id,o.name,o.sport_code,o.city_code,s.label,o.starts_on,o.ends_on
 from public.organizations o join public.sport_seasons s on s.id=o.sport_season_id
 where o.official and o.is_public order by o.starts_on,o.id
$$;
revoke all on function public.public_sport_programs() from public,anon,authenticated;
grant execute on function public.public_sport_programs() to anon,authenticated;

drop function if exists public.public_program_fixture(uuid);
create function public.public_program_fixture(p_org uuid)
returns table(id uuid,starts_at timestamptz,location text,home_name text,away_name text,status text)
language sql stable security definer set search_path=public as $$
 -- Official participant names are validated legal club names by federation_guard.
 -- This frozen legal name survives club deletion; no team/athlete name fallback.
 select m.id,m.starts_at,m.location,h.name,a.name,m.status
 from public.organizations o join public.org_matches m on m.org_id=o.id
 left join public.org_participants h on h.id=m.home_id and h.org_id=o.id
 left join public.org_participants a on a.id=m.away_id and a.org_id=o.id
 where o.id=p_org and o.official and o.is_public order by m.starts_at,m.id
$$;
revoke all on function public.public_program_fixture(uuid) from public,anon,authenticated;
grant execute on function public.public_program_fixture(uuid) to anon,authenticated;

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
      or at.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date
      or exists(select 1 from public.guardians g where g.athlete_id=at.id))
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

-- Close direct guest reads, including the legacy owner-security athlete view.
-- Existing authenticated grants and policies are untouched. Optional names allow
-- reduced local fixtures; in the complete migration sequence these already exist.
do $$ declare v_name text; begin
 foreach v_name in array array[
 'organizations','org_matches','org_participants','federations','federation_offices',
 'sport_seasons','federation_appointments','federation_audit','club_sport_registrations',
 'org_result_revisions','org_roster_revisions','athlete_sport_registrations','athlete_transfers',
 'official_disputes','athlete_publicity','athletes','athlete_public','athlete_achievements',
 'profiles','guardians','profile_credentials','verification_documents','team_memberships',
 'club_memberships','teams','health_restrictions','invoices','payments','attendance',
 'attendance_audit_log','attendance_op_logs','documents','events','development_goals',
 'training_protocols','training_sessions','training_session_participants','training_sets',
 'training_set_entries','training_session_events','training_self_assessments',
 'athlete_nutrition_logs','athlete_nutrition_targets'] loop
  if to_regclass(format('public.%I',v_name)) is not null then
   execute format('revoke select on public.%I from public,anon',v_name);
  end if;
 end loop;
end $$;
