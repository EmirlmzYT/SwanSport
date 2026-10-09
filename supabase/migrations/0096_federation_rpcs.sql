-- Phase A callable foundation. Every official mutation checks scope and audits atomically.
set local lock_timeout = '15s';

drop function if exists public.federation_create_office(text,text,text,text);
create function public.federation_create_office(p_sport text,p_federation_name text,p_city text,p_office_name text)
returns uuid language plpgsql security definer set search_path=public as $$
declare f uuid;v uuid;
begin
 if not public.is_platform_admin() then raise exception 'Kurum kurulumu platform yöneticisi gerektirir'; end if;
 insert into public.federations(sport_code,name) values(p_sport,p_federation_name)
 on conflict(sport_code) do update set name=excluded.name returning id into f;
 insert into public.federation_offices(federation_id,city_code,name) values(f,p_city,p_office_name)
 on conflict(federation_id,city_code) do update set name=excluded.name returning id into v;
 insert into public.federation_audit(actor_id,action,entity_id) values(auth.uid(),'office_setup',v);
 return v;
end $$;
drop function if exists public.federation_appoint(uuid,uuid,text,date,date);
create function public.federation_appoint(p_office uuid,p_profile uuid,p_duty text,p_starts date,p_ends date)
returns uuid language plpgsql security definer set search_path=public as $$
declare v uuid;
begin
 if not public.is_platform_admin() then raise exception 'Görev ataması platform yöneticisi gerektirir'; end if;
 insert into public.federation_appointments(profile_id,office_id,duty,starts_on,ends_on,granted_by)
 values(p_profile,p_office,p_duty,p_starts,p_ends,auth.uid()) returning id into v;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id) values(auth.uid(),v,'appoint',v);return v;
end $$;
drop function if exists public.federation_revoke_appointment(uuid);
create function public.federation_revoke_appointment(p_appointment uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_platform_admin() then raise exception 'Görev iptali platform yöneticisi gerektirir'; end if;
 update public.federation_appointments set revoked_at=clock_timestamp() where id=p_appointment and revoked_at is null;
 if not found then raise exception 'Aktif görev bulunamadı'; end if;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id) values(auth.uid(),p_appointment,'revoke',p_appointment);
end $$;

drop function if exists public.federation_open_season(uuid,text,date,date);
create function public.federation_open_season(p_office uuid,p_label text,p_starts date,p_ends date)
returns uuid language plpgsql security definer set search_path=public as $$
declare s text;c text;a uuid;v uuid;
begin
 select f.sport_code,o.city_code into s,c from public.federation_offices o join public.federations f on f.id=o.federation_id where o.id=p_office;
 a:=public._federation_require(s,c,'program_publisher');
 insert into public.sport_seasons(office_id,label,starts_on,ends_on) values(p_office,p_label,p_starts,p_ends) returning id into v;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id) values(auth.uid(),a,'season_create',v);return v;
end $$;
drop function if exists public.federation_register_club(uuid,text,text,text,text);
create function public.federation_register_club(p_club uuid,p_sport text,p_legal_name text,p_registration_no text,p_city text)
returns void language plpgsql security definer set search_path=public as $$
declare a uuid;v public.clubs;
begin
 a:=public._federation_require(p_sport,p_city,'club_registrar');
 select * into v from public.clubs where id=p_club for update;
 if v.id is null or nullif(trim(p_legal_name),'') is null or nullif(trim(p_registration_no),'') is null or p_city is null then raise exception 'Tescil bilgileri eksik'; end if;
 if v.registration_city_code is not null then perform public._federation_require(p_sport,v.registration_city_code,'club_registrar'); end if;
 -- First registration defines shared legal identity. Other sports cannot rewrite it.
 if v.registration_status='approved' and (v.legal_name,v.registration_city_code) is distinct from(p_legal_name,p_city) then raise exception 'Mevcut yasal kimlik değiştirilemez'; end if;
 if v.registration_status<>'approved' then
  update public.clubs set legal_name=p_legal_name,registration_no=p_registration_no,registration_city_code=p_city,registration_sport_code=p_sport,registration_status='approved' where id=p_club;
 end if;
 insert into public.club_sport_registrations(club_id,sport_code,registration_no,approved_on) values(p_club,p_sport,p_registration_no,current_date)
 on conflict(club_id,sport_code) do update set registration_no=excluded.registration_no,approved_on=excluded.approved_on;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail) values(auth.uid(),a,'club_registration',p_club,jsonb_build_object('sport',p_sport));
end $$;

drop function if exists public.federation_create_program(uuid,text,text,date,date);
create function public.federation_create_program(p_season uuid,p_name text,p_city text,p_starts date,p_ends date)
returns uuid language plpgsql security definer set search_path=public as $$
declare v uuid;s text;o uuid;c text;
begin
 select f.sport_code,ss.office_id,fo.city_code into s,o,c from public.sport_seasons ss
 join public.federation_offices fo on fo.id=ss.office_id join public.federations f on f.id=fo.federation_id where ss.id=p_season;
 perform public._federation_require(s,p_city,'program_publisher');
 if c is not null and c is distinct from p_city then raise exception 'Ofis ili uyuşmuyor'; end if;
 insert into public.organizations(name,sport_code,city_code,starts_on,ends_on,federation_office_id,sport_season_id,official,is_public,published_at)
 values(p_name,s,p_city,p_starts,p_ends,o,p_season,true,false,clock_timestamp()) returning id into v;return v;
end $$;
drop function if exists public.federation_add_participant(uuid,uuid,uuid);
create function public.federation_add_participant(p_org uuid,p_club uuid,p_team uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v uuid;o public.organizations;
begin
 select * into o from public.organizations where id=p_org and official for update;
 perform public._federation_require(o.sport_code,o.city_code,'program_publisher');
 insert into public.org_participants(org_id,club_id,team_id,name,status)
 select p_org,p_club,p_team,legal_name,'accepted' from public.clubs where id=p_club returning id into v;
 if v is null then raise exception 'Kulüp bulunamadı'; end if;return v;
end $$;
drop function if exists public.federation_schedule_match(uuid,uuid,uuid,timestamptz);
create function public.federation_schedule_match(p_org uuid,p_home uuid,p_away uuid,p_starts timestamptz)
returns uuid language plpgsql security definer set search_path=public as $$
declare o public.organizations;v uuid;
begin
 select * into o from public.organizations where id=p_org and official for update;
 perform public._federation_require(o.sport_code,o.city_code,'program_publisher');
 if p_starts is null or (p_starts at time zone 'Europe/Istanbul')::date not between o.starts_on and o.ends_on or p_home=p_away then raise exception 'Maç tarihi/tarafları geçersiz'; end if;
 insert into public.org_matches(org_id,home_id,away_id,starts_at) values(p_org,p_home,p_away,p_starts) returning id into v;return v;
end $$;

drop function if exists public.federation_publish_roster(uuid,uuid[],text,int);
create function public.federation_publish_roster(p_participant uuid,p_athletes uuid[],p_reason text,p_expected_version int)
returns uuid language plpgsql security definer set search_path=public as $$
declare p public.org_participants;o public.organizations;a uuid;v uuid;n int;
begin
 select * into p from public.org_participants where id=p_participant for update;
 select * into o from public.organizations where id=p.org_id and official;
 a:=public._federation_require(o.sport_code,o.city_code,'program_publisher');
 select coalesce(max(version),0) into n from public.org_roster_revisions where participant_id=p.id;
 if p_expected_version is distinct from n then raise exception 'Kadro sürümü değişti'; end if;
 if p_reason is null or length(trim(p_reason)) not between 1 and 500 or cardinality(p_athletes) not between 1 and 200
 or p_athletes is null or array_position(p_athletes,null) is not null
 or cardinality(p_athletes)<>(select count(distinct x) from unnest(p_athletes) x) then raise exception 'Kadro/gerekçe geçersiz'; end if;
 if exists(select 1 from unnest(p_athletes) x where not exists(select 1 from public.athletes at
 join public.athlete_sport_registrations r on r.athlete_id=at.id
 where at.id=x and r.sport_code=o.sport_code and r.club_id=p.club_id and r.expires_on>=o.ends_on
 and (p.team_id is null or exists(select 1 from public.team_memberships tm where tm.team_id=p.team_id and tm.athlete_id=at.id))
 and not exists(select 1 from public.eligibility_gate(at.id) g where g.blocked and g.reason_code<>'license_expired'))) then raise exception 'Kadro branş/kulüp/takım/lisans/uygunluk şartını karşılamıyor'; end if;
 insert into public.org_roster_revisions(participant_id,version,athlete_ids,reason,actor_id) values(p.id,n+1,p_athletes,p_reason,auth.uid()) returning id into v;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail) values(auth.uid(),a,'roster_revision',v,jsonb_build_object('version',n+1));return v;
end $$;

-- Protocol is an explicit allowlist: no arbitrary JSON capable of embedding names/medical data.
drop function if exists public._valid_official_protocol(jsonb);
create function public._valid_official_protocol(p jsonb) returns boolean language plpgsql immutable as $$
declare x jsonb;t text;
begin
 if jsonb_typeof(p) is distinct from 'object' then return false; end if;
 t:=p->>'type';
 if t='score' then
  if p-array['type','home','away']<>'{}'::jsonb then return false; end if;
  return coalesce(jsonb_typeof(p->'home')='number' and jsonb_typeof(p->'away')='number' and (p->>'home')~'^[0-9]{1,6}$' and (p->>'away')~'^[0-9]{1,6}$',false);
 elsif t='sets' then
  if p-array['type','sets']<>'{}'::jsonb or jsonb_typeof(p->'sets') is distinct from 'array' then return false; end if;
  if jsonb_array_length(p->'sets') not between 1 and 15 then return false; end if;
  for x in select * from jsonb_array_elements(p->'sets') loop
   if jsonb_typeof(x) is distinct from 'object' then return false; end if;
   if x-array['home','away']<>'{}'::jsonb or not coalesce(jsonb_typeof(x->'home')='number' and jsonb_typeof(x->'away')='number' and (x->>'home')~'^[0-9]{1,6}$' and (x->>'away')~'^[0-9]{1,6}$',false) then return false; end if;
  end loop;return true;
 elsif t in ('time','rank') then
  if p-array['type','entries']<>'{}'::jsonb or jsonb_typeof(p->'entries') is distinct from 'array' then return false; end if;
  if jsonb_array_length(p->'entries') not between 1 and 200 then return false; end if;
  for x in select * from jsonb_array_elements(p->'entries') loop
   if jsonb_typeof(x) is distinct from 'object' then return false; end if;
   if x-array['athlete_id','value','placement']<>'{}'::jsonb or not coalesce(
    jsonb_typeof(x->'value')='number' and jsonb_typeof(x->'placement')='number' and     (x->>'athlete_id')~'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
    and (x->>'value')~'^[0-9]{1,12}(\.[0-9]{1,6})?$' and (x->>'placement')~'^[1-9][0-9]{0,5}$',false) then return false; end if;
  end loop;
  return (select count(*)=count(distinct e->>'athlete_id') from jsonb_array_elements(p->'entries') e);
 end if;return false;
end $$;
revoke all on function public._valid_official_protocol(jsonb) from public,anon,authenticated;

drop function if exists public.federation_publish_result(uuid,jsonb,text,int);
create function public.federation_publish_result(p_match uuid,p_protocol jsonb,p_reason text,p_expected_version int)
returns uuid language plpgsql security definer set search_path=public as $$
declare m public.org_matches;o public.organizations;a uuid;v uuid;home_roster uuid;away_roster uuid;
begin
 select * into m from public.org_matches where id=p_match for update;
 select * into o from public.organizations where id=m.org_id and official;
 a:=public._federation_require(o.sport_code,o.city_code,'result_publisher');
 if m.result_version is distinct from p_expected_version then raise exception 'Sonuç sürümü değişti'; end if;
 if not public._valid_official_protocol(p_protocol) or p_reason is null or length(trim(p_reason)) not between 1 and 500 then raise exception 'Sonuç protokolü/gerekçe geçersiz'; end if;
 -- Serialize roster publication with the result snapshot; fixed UUID order avoids reversed-side deadlocks.
 perform 1 from public.org_participants where id in(m.home_id,m.away_id) order by id for share;
 select id into home_roster from public.org_roster_revisions where participant_id=m.home_id order by version desc limit 1;
 select id into away_roster from public.org_roster_revisions where participant_id=m.away_id order by version desc limit 1;
 if home_roster is null or (m.away_id is not null and away_roster is null) then raise exception 'Önce resmi kadro yayımlanmalı'; end if;
 if p_protocol->>'type' in ('time','rank') and exists(select 1 from jsonb_array_elements(p_protocol->'entries') e
 where not exists(select 1 from public.org_roster_revisions r where r.participant_id in(m.home_id,m.away_id)
 and r.version=(select max(r2.version) from public.org_roster_revisions r2 where r2.participant_id=r.participant_id)
 and (e->>'athlete_id')::uuid=any(r.athlete_ids))) then raise exception 'Sonuç sporcusu güncel resmi kadroda yok'; end if;
 insert into public.org_result_revisions(match_id,version,protocol,reason,actor_id,home_roster_revision_id,away_roster_revision_id) values(m.id,m.result_version+1,p_protocol,p_reason,auth.uid(),home_roster,away_roster) returning id into v;
 update public.org_matches set result_protocol=p_protocol,result_version=m.result_version+1,status='played',
 home_score=case when p_protocol->>'type'='score' then (p_protocol->>'home')::int end,
 away_score=case when p_protocol->>'type'='score' then (p_protocol->>'away')::int end where id=m.id;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail) values(auth.uid(),a,'result_revision',v,jsonb_build_object('version',m.result_version+1));return v;
end $$;

drop function if exists public.federation_award_achievement(uuid,uuid,text,int,uuid);
create function public.federation_award_achievement(p_match uuid,p_athlete uuid,p_title text,p_placement int,p_supersedes uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare m public.org_matches;o public.organizations;r uuid;v uuid;
begin
 select * into m from public.org_matches where id=p_match for update;
 select * into o from public.organizations where id=m.org_id and official;
 perform public._federation_require(o.sport_code,o.city_code,'result_publisher');
 select id into r from public.org_result_revisions where match_id=m.id and version=m.result_version;
 if r is null or p_title is null or length(trim(p_title)) not between 1 and 180 or p_placement is null or p_placement<1 then raise exception 'Yayımlanmış sonuç ve derece gerekli'; end if;
 insert into public.athlete_achievements(athlete_id,title,placement,event_date,source,source_id,official_match_id,supersedes_id,verified,created_by)
 values(p_athlete,p_title,p_placement,(m.starts_at at time zone 'Europe/Istanbul')::date,'federation_result',r,m.id,p_supersedes,true,auth.uid()) returning id into v;return v;
end $$;

drop function if exists public.federation_register_license(uuid,text,text,date);
create function public.federation_register_license(p_athlete uuid,p_sport text,p_number text,p_expires date)
returns void language plpgsql security definer set search_path=public as $$
declare at public.athletes;c public.clubs;a uuid;old_expiry date;old_number text;
begin
 perform pg_advisory_xact_lock(940096);
 select * into at from public.athletes where id=p_athlete for update;
 select * into c from public.clubs where id=at.club_id;
 a:=public._federation_require(p_sport,c.registration_city_code,'license_registrar');
 if at.id is null or p_expires is null or p_number is null or length(trim(p_number)) not between 1 and 80
 or not exists(select 1 from public.club_sport_registrations where club_id=at.club_id and sport_code=p_sport) then raise exception 'Sporcu/lisans/tescil bilgisi eksik'; end if;
 if exists(select 1 from public.athlete_sport_registrations where athlete_id=at.id and sport_code=p_sport and club_id is distinct from at.club_id) then raise exception 'Kulüp değişikliği transfer kaydı gerektirir'; end if;
 select expires_on,license_number into old_expiry,old_number from public.athlete_sport_registrations where athlete_id=at.id and sport_code=p_sport;
 insert into public.athlete_sport_registrations(athlete_id,sport_code,club_id,license_number,expires_on) values(at.id,p_sport,at.club_id,trim(p_number),p_expires)
 on conflict(athlete_id,sport_code) do update set license_number=excluded.license_number,expires_on=excluded.expires_on;
 -- Existing gate keeps reading the original primary-sport column.
 if c.sport_code=p_sport then update public.athletes set license_expires_on=p_expires where id=at.id; end if;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail) values(auth.uid(),a,'license_revision',at.id,
 jsonb_build_object('sport',p_sport,'previous_expires_on',old_expiry,'expires_on',p_expires,'previous_license_number',old_number,'license_number',trim(p_number)));
end $$;

drop function if exists public.federation_transfer_athlete(uuid,text,uuid,text);
create function public.federation_transfer_athlete(p_athlete uuid,p_sport text,p_to_club uuid,p_reason text)
returns uuid language plpgsql security definer set search_path=public as $$
declare r public.athlete_sport_registrations;old_c public.clubs;new_c public.clubs;a uuid;v uuid;
begin
 perform pg_advisory_xact_lock(940096);
 select * into r from public.athlete_sport_registrations where athlete_id=p_athlete and sport_code=p_sport for update;
 select * into old_c from public.clubs where id=r.club_id;
 select * into new_c from public.clubs where id=p_to_club;
 a:=public._federation_require(p_sport,old_c.registration_city_code,'license_registrar');
 perform public._federation_require(p_sport,new_c.registration_city_code,'license_registrar');
 if r.athlete_id is null or r.club_id=p_to_club or p_reason is null or length(trim(p_reason)) not between 1 and 500
 or not exists(select 1 from public.club_sport_registrations where club_id=p_to_club and sport_code=p_sport) then raise exception 'Transfer bilgileri geçersiz'; end if;
 insert into public.athlete_transfers(athlete_id,sport_code,from_club_id,to_club_id,transferred_on,reason)
 values(p_athlete,p_sport,r.club_id,p_to_club,current_date,p_reason) returning id into v;
 update public.athlete_sport_registrations set club_id=p_to_club where athlete_id=p_athlete and sport_code=p_sport;
 -- Primary roster ownership follows the official transfer, old match snapshots remain intact.
 if old_c.sport_code=p_sport then
  delete from public.team_memberships where athlete_id=p_athlete;
  update public.athletes set club_id=p_to_club where id=p_athlete;
 end if;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail) values(auth.uid(),a,'transfer',v,jsonb_build_object('sport',p_sport));return v;
end $$;

-- Private de-duplication: no lookup oracle for clubs or guests; lock covers legacy writes too.
drop trigger if exists federation_identity_guard on public.athletes;
drop function if exists public._athlete_identity_guard();
create function public._athlete_identity_guard() returns trigger language plpgsql security definer set search_path=public as $$
begin
 perform pg_advisory_xact_lock(940096);
 if exists(select 1 from public.athletes a where a.id<>new.id and (
  (nullif(trim(new.national_id),'') is not null and trim(a.national_id)=trim(new.national_id)) or
  (nullif(trim(new.license_number),'') is not null and trim(a.license_number)=trim(new.license_number))))
 or exists(select 1 from public.athlete_sport_registrations r join public.clubs c on c.id=new.club_id
  where r.athlete_id<>new.id and r.sport_code=c.sport_code and r.license_number=nullif(trim(new.license_number),'')) then
  raise exception 'Kimlik eşleşmesi var; yeni kayıt yerine yetkili bağlama gerekli'; end if;
 return new;
end $$;
revoke all on function public._athlete_identity_guard() from public,anon,authenticated;
create trigger federation_identity_guard before insert or update of national_id,license_number on public.athletes for each row execute function public._athlete_identity_guard();
drop function if exists public.federation_find_or_create_athlete(uuid,text,text,text,text,text);
create function public.federation_find_or_create_athlete(p_club uuid,p_sport text,p_first text,p_last text,p_license text,p_national_id text)
returns uuid language plpgsql security definer set search_path=public as $$
declare a uuid;v uuid;ids uuid[];c public.clubs;
begin
 select * into c from public.clubs where id=p_club;
 a:=public._federation_require(p_sport,c.registration_city_code,'license_registrar');
 if not exists(select 1 from public.club_sport_registrations where club_id=p_club and sport_code=p_sport)
 or (nullif(trim(p_license),'') is null and nullif(trim(p_national_id),'') is null) then raise exception 'Tescilli kulüp ve kimlik/lisans gerekli'; end if;
 perform pg_advisory_xact_lock(940096);
 select array_agg(k.id) into ids from (
 select at.id from public.athletes at where
 (nullif(trim(p_license),'') is not null and trim(at.license_number)=trim(p_license)) or
 (nullif(trim(p_national_id),'') is not null and trim(at.national_id)=trim(p_national_id))
 union
 select r.athlete_id from public.athlete_sport_registrations r
 where r.sport_code=p_sport and r.license_number=nullif(trim(p_license),'')) k;
 if cardinality(ids)>1 then raise exception 'Eski kimlik çakışması; manuel inceleme gerekli'; end if;
 v:=ids[1];
 if v is not null then
  if not exists(select 1 from public.athletes where id=v) then
   perform public._federation_require(p_sport,null,'license_registrar');
   insert into public.athletes(id,club_id,first_name,last_name,license_number,national_id) values(v,p_club,p_first,p_last,nullif(trim(p_license),''),nullif(trim(p_national_id),''));
  end if;
  if nullif(trim(p_national_id),'') is not null and exists(select 1 from public.athletes where id=v and nullif(trim(national_id),'') is not null and trim(national_id)<>trim(p_national_id)) then raise exception 'Kimlik/lisans eşleşmesi çelişkili'; end if;
  if exists(select 1 from public.athletes at join public.clubs cl on cl.id=at.club_id where at.id=v and cl.registration_city_code is distinct from c.registration_city_code) then
   perform public._federation_require(p_sport,null,'license_registrar'); end if;
 else
  insert into public.athletes(club_id,first_name,last_name,license_number,national_id)
  values(p_club,p_first,p_last,nullif(trim(p_license),''),nullif(trim(p_national_id),'')) returning id into v;
 end if;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id) values(auth.uid(),a,'athlete_resolve',v);return v;
end $$;

-- Guardian consent is relational and revocable; nothing snapshots the child's name.
drop function if exists public.set_athlete_publicity(uuid,boolean);
create function public.set_athlete_publicity(p_athlete uuid,p_allowed boolean)
returns void language plpgsql security definer set search_path=public as $$
declare g uuid;
begin
 select id into g from public.guardians where athlete_id=p_athlete and profile_id=auth.uid() order by id limit 1 for share;
 if g is null or p_allowed is null then raise exception 'Veli bağlantısı gerekli'; end if;
 insert into public.athlete_publicity(athlete_id,guardian_id,allowed) values(p_athlete,g,p_allowed)
 on conflict(athlete_id,guardian_id) do update set allowed=excluded.allowed,updated_at=clock_timestamp();
end $$;

drop function if exists public.federation_submit_dispute(uuid,text,uuid);
create function public.federation_submit_dispute(p_match uuid,p_body text,p_responds_to uuid default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare m public.org_matches;o public.organizations;v uuid;a uuid;
begin
 select * into m from public.org_matches where id=p_match for share;
 select * into o from public.organizations where id=m.org_id and official;
 a:=public._federation_require(o.sport_code,o.city_code,'result_publisher');
 if p_responds_to is not null and not exists(select 1 from public.official_disputes where id=p_responds_to and match_id=m.id) then raise exception 'İtiraz kaynağı yanlış'; end if;
 insert into public.official_disputes(match_id,submitted_by,body,responds_to) values(m.id,auth.uid(),p_body,p_responds_to) returning id into v;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id) values(auth.uid(),a,'dispute_append',v);return v;
end $$;

-- Authenticated, appointment-scoped card only; zero health/dues/identity/document fields.
drop function if exists public.federation_result_card(uuid);
create function public.federation_result_card(p_match uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare m public.org_matches;o public.organizations;
begin
 select * into m from public.org_matches where id=p_match;
 select * into o from public.organizations where id=m.org_id and official;
 perform public._federation_require(o.sport_code,o.city_code,'result_publisher');
 return jsonb_build_object('match_id',m.id,'sport_code',o.sport_code,'category',o.age_group,'protocol',m.result_protocol,'version',m.result_version,
 'athletes',coalesce((select jsonb_agg(jsonb_build_object('athlete_id',k.id,'name',case
  when at.id is null then null
  when (at.birth_date is null or at.birth_date>current_date-interval '18 years' or exists(select 1 from public.guardians g where g.athlete_id=at.id))
   and (not exists(select 1 from public.athlete_publicity ap join public.guardians g on g.id=ap.guardian_id
    where ap.athlete_id=at.id and g.profile_id is not null and ap.allowed)
    or exists(select 1 from public.athlete_publicity ap join public.guardians g on g.id=ap.guardian_id
    where ap.athlete_id=at.id and g.profile_id is not null and not ap.allowed))
  then null else trim(at.first_name||' '||at.last_name) end))
 from (select distinct unnest(r.athlete_ids) id from public.org_roster_revisions r where r.participant_id in(m.home_id,m.away_id)
  and ((m.result_version=0 and r.version=(select max(r2.version) from public.org_roster_revisions r2 where r2.participant_id=r.participant_id))
    or exists(select 1 from public.org_result_revisions rv where rv.match_id=m.id and rv.version=m.result_version
       and r.id in(rv.home_roster_revision_id,rv.away_roster_revision_id)))) k
 left join public.athletes at on at.id=k.id),'[]'::jsonb));
end $$;

-- Explicit whitelist. Helpers/triggers remain uncallable even with default PUBLIC privileges.
do $$ declare r record;begin
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('federation_create_office','federation_appoint','federation_revoke_appointment',
 'federation_open_season','federation_register_club','federation_create_program','federation_add_participant','federation_schedule_match',
 'federation_publish_roster','federation_publish_result','federation_award_achievement','federation_register_license','federation_transfer_athlete',
 'federation_find_or_create_athlete','set_athlete_publicity','federation_submit_dispute','federation_result_card') loop
 execute format('revoke all on function %s from public,anon,authenticated',r.sig);
 execute format('grant execute on function %s to authenticated',r.sig);
 end loop;
end $$;

drop function if exists public.my_federation_appointments();
create function public.my_federation_appointments()
returns table(id uuid,sport_code text,city_code text,duty text,starts_on date,ends_on date,revoked_at timestamptz)
language sql stable security definer set search_path=public as $$
 select a.id,f.sport_code,o.city_code,a.duty,a.starts_on,a.ends_on,a.revoked_at
 from public.federation_appointments a join public.federation_offices o on o.id=a.office_id
 join public.federations f on f.id=o.federation_id where a.profile_id=auth.uid()
$$;
revoke all on function public.my_federation_appointments() from public,anon,authenticated;
grant execute on function public.my_federation_appointments() to authenticated;

-- Global identity lock precedes row locks even for legacy direct writes.
drop trigger if exists federation_identity_statement_lock on public.athletes;
drop function if exists public._athlete_identity_statement_lock();
create function public._athlete_identity_statement_lock() returns trigger language plpgsql security definer set search_path=public as $$
begin perform pg_advisory_xact_lock(940096);return null;end $$;
revoke all on function public._athlete_identity_statement_lock() from public,anon,authenticated;
create trigger federation_identity_statement_lock before insert or update on public.athletes
 for each statement execute function public._athlete_identity_statement_lock();
