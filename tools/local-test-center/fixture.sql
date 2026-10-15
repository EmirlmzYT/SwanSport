-- SYNTHETIC FIXTURES: NEVER paste into a hosted/production SQL Editor.
-- Only tools/start_local_test_center.mjs, pinned local Docker container.
begin;
set local lock_timeout='15s';
do $fixture$
declare
 manager uuid := md5('swansport-live-role-tests-v2/kulup-yoneticisi')::uuid;
 coach uuid := md5('swansport-live-role-tests-v2/antrenor-3')::uuid;
 athlete uuid := md5('swansport-live-role-tests-v2/lisansli-sporcu')::uuid;
 club uuid := '53570000-0000-4000-8000-000000000001';
 team uuid := '53570000-0000-4000-8000-000000000010';
 season uuid := '53570000-0000-4000-8000-000000000011';
 athlete_row uuid := '53570000-0000-4000-8000-000000000012';
 credential uuid;
 person uuid;
 idx int := 0;
begin
 if to_regclass('public._local_test_center_install') is null then
  raise exception 'LOCAL TEST ONLY: launcher marker missing; do not run in production';
 end if;
 if not exists(select 1 from public._local_test_center_install where project='swansport-test-center') then
  raise exception 'LOCAL TEST ONLY: wrong project';
 end if;
 -- Local-only fixture reviewer, revoked before committing. No client bypass/trigger disable.
 update public.profiles set is_platform_admin=true where id=manager;
 perform set_config('request.jwt.claim.sub',manager::text,true);
 foreach person in array array[manager,coach,athlete] loop
  idx:=idx+1;
  insert into public.profile_credentials(profile_id,kind)
   values(person,'identity') on conflict(profile_id) where kind='identity' do nothing;
  select id into credential from public.profile_credentials where profile_id=person and kind='identity';
  if not exists(select 1 from public.verification_documents where owner_id=credential
   and owner_type='credential' and doc_type='kimlik') then
   insert into public.verification_documents(owner_type,owner_id,doc_type,storage_path,uploaded_by)
   values('credential',credential,'kimlik',person::text||'/LOCAL-SYNTHETIC-FIXTURE.txt',person);
  end if;
  -- Only this disposable local fixture contains synthetic identity values.
  perform public.review_credential(credential,true,'LOCAL SYNTHETIC FIXTURE',null,null,
   case idx when 1 then '11111111110' when 2 then '22222222220' else '33333333330' end,null);
  if not exists(select 1 from public.profile_credentials where profile_id=person
   and kind<>'identity' and sport_code='futbol') then
   insert into public.profile_credentials(profile_id,kind,coach_level,sport_code,expires_on)
   values(person,(case when person=athlete then 'athlete_licensed' else 'coach' end)::public.credential_kind,
    case when person<>athlete then 3 end,'futbol',current_date+365) returning id into credential;
   perform public.review_credential(credential,true,'LOCAL SYNTHETIC FIXTURE');
  end if;
 end loop;
 update public.clubs set status='active' where id=club;
 if not exists(select 1 from public.club_memberships where club_id=club and profile_id=manager and role='club_admin') then
  insert into public.club_memberships(club_id,profile_id,role) values(club,manager,'club_admin');
 end if;
 if not exists(select 1 from public.club_memberships where club_id=club and profile_id=coach and role='coach') then
  insert into public.club_memberships(club_id,profile_id,role,coach_level) values(club,coach,'coach',3);
 end if;
 if not exists(select 1 from public.club_memberships where club_id=club and profile_id=athlete and role='athlete') then
  insert into public.club_memberships(club_id,profile_id,role) values(club,athlete,'athlete');
 end if;
 insert into public.seasons(id,club_id,label,starts_on,ends_on,is_active)
 values(season,club,'[TEST] Yerel Sezon',current_date,current_date+365,true) on conflict(id) do nothing;
 insert into public.teams(id,club_id,name,sport_code)
 values(team,club,'[TEST] Yetişkin Futbol Takımı','futbol') on conflict(id) do nothing;
 insert into public.athletes(id,club_id,profile_id,first_name,last_name,birth_date)
 values(athlete_row,club,athlete,'Test','Sporcu','1995-06-15') on conflict(id) do nothing;
 insert into public.team_memberships(athlete_id,team_id,season_id,jersey_number)
 values(athlete_row,team,season,'10') on conflict(athlete_id,team_id,season_id) do nothing;
 insert into public.events(id,club_id,team_id,title,kind,place,starts_at,ends_at)
 values('53570000-0000-4000-8000-000000000013',club,team,'[TEST] Yoklama Antrenmanı','training',
  '[TEST] Yerel saha',now()+interval '1 hour',now()+interval '2 hours') on conflict(id) do nothing;
 insert into public.invoices(id,club_id,athlete_id,label,amount,status,period)
 values('53570000-0000-4000-8000-000000000014',club,athlete_row,'[TEST] Aidat',1500,'pending',
  to_char(current_date,'YYYY-MM')) on conflict(id) do nothing;
 update public.profiles set is_platform_admin=false where id=manager;
 perform set_config('request.jwt.claim.sub','',true);
end
$fixture$;
commit;
