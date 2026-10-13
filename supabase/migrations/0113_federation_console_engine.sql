set local lock_timeout = '15s';

-- No new public projections or legacy federation-write bypasses.
create or replace function public._console_federation_scope(p_sport text,p_city text,p_roles text[])
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and exists (
  select 1 from federation_roles r join federations f on f.id=r.federation_id
  where r.profile_id=auth.uid() and f.sport_code=p_sport and r.revoked_at is null
   and (clock_timestamp() at time zone 'Europe/Istanbul')::date between r.starts_on and r.ends_on
   and (r.role='president' or (r.role=any(p_roles) and (r.role<>'provincial_rep' or r.city_code=p_city))))
$$;

-- Allocation is not a duplicate match/event. Only the venue-owning club's
-- active staff can record its own official fixture's venue/time interval.
create table if not exists public.official_match_facilities (
 match_id uuid primary key references public.org_matches(id) on delete restrict,
 facility_id uuid not null references public.facilities(id) on delete restrict,
 starts_at timestamptz not null,ends_at timestamptz not null check(ends_at>starts_at),
 allocated_by uuid references public.profiles(id) on delete set null,
 updated_at timestamptz not null default clock_timestamp());
alter table public.official_match_facilities enable row level security;
revoke all on public.official_match_facilities from public,anon,authenticated;

create or replace function public.allocate_official_match_facility(p_match_id uuid,p_facility_id uuid,p_ends_at timestamptz)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare m org_matches;f facilities;begin
 if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
 perform 1 from profiles where id=auth.uid() for key share;
 perform pg_advisory_xact_lock(113,0);
 perform pg_advisory_xact_lock(110,hashtext(p_match_id::text));
 select * into m from org_matches where id=p_match_id for update;
 select * into f from facilities where id=p_facility_id for share;
 if f.id is null or not public.is_club_staff(f.club_id) or not exists(select 1 from org_participants p
  join organizations o on o.id=p.org_id where p.id in(m.home_id,m.away_id) and p.club_id=f.club_id and o.official) then
  raise exception 'Tesis sahibi katılımcı kulübün aktif personeli gerekli' using errcode='42501'; end if;
 if m.status<>'scheduled' or exists(select 1 from match_lineup_approvals where match_id=m.id) then raise exception 'Maç/esame kilitli' using errcode='55000'; end if;
 if m.starts_at is null or p_ends_at is null or p_ends_at<=m.starts_at or p_ends_at>m.starts_at+interval '24 hours' then
  raise exception 'Kesin maç saat aralığı gerekli' using errcode='22023'; end if;
 insert into official_match_facilities(match_id,facility_id,starts_at,ends_at,allocated_by)
 values(m.id,f.id,m.starts_at,p_ends_at,auth.uid()) on conflict(match_id) do update set
 facility_id=excluded.facility_id,starts_at=excluded.starts_at,ends_at=excluded.ends_at,allocated_by=auth.uid(),updated_at=clock_timestamp();
 insert into federation_audit(actor_id,action,entity_id,detail) values(auth.uid(),'official_facility_allocated',m.id,
  jsonb_build_object('facility_id',f.id,'ends_at',p_ends_at));
end $$;

-- Raw rows include private excuses: provinces must use the redacted RPC.
create or replace function public._sports_assignment_read(p_match uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from org_matches m join organizations o on o.id=m.org_id
  where m.id=p_match and o.official and public._console_federation_scope(o.sport_code,o.city_code,array['referee_committee']))
$$;

create or replace function public.federation_console_scopes()
returns table(federation_id uuid,federation_name text,sport_code text,city_code text,role text)
language sql stable security definer set search_path=public,pg_temp as $$
 select f.id,f.name,f.sport_code,r.city_code,r.role from federation_roles r join federations f on f.id=r.federation_id
 where r.profile_id=auth.uid() and r.revoked_at is null
  and (clock_timestamp() at time zone 'Europe/Istanbul')::date between r.starts_on and r.ends_on
 order by f.sport_code,r.city_code,r.role
$$;

drop function if exists public.federation_console_matches(text,int,text);
create or replace function public.federation_console_matches(p_city text default null,p_offset int default 0,p_search text default '',
 p_from timestamptz default null,p_until timestamptz default null)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 with scoped as (
 select m.id,o.name as program,o.sport_code,o.city_code,m.starts_at,m.location,m.status,h.name as home_name,a.name as away_name,
  f.name as facility_name,
  case when e.facility_id is not null and e.ends_at>e.starts_at and e.starts_at=m.starts_at and m.status<>'cancelled'
   then (select count(*) from public.events other_event where other_event.facility_id=e.facility_id
    and other_event.status<>'cancelled' and other_event.starts_at<e.ends_at
    and coalesce(other_event.ends_at,other_event.starts_at+interval '90 minutes')>e.starts_at)
    +(select count(*) from public.facility_reservations reservation where reservation.facility_id=e.facility_id
     and reservation.status in ('pending','confirmed') and reservation.starts_at<e.ends_at and reservation.ends_at>e.starts_at)
    +(select count(*) from official_match_facilities other_allocation join org_matches other_match on other_match.id=other_allocation.match_id
     where other_allocation.facility_id=e.facility_id and other_allocation.match_id<>m.id and other_match.status<>'cancelled'
      and other_allocation.starts_at<e.ends_at and other_allocation.ends_at>e.starts_at)
   end as facility_conflict_count,
  coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'duty',x.duty,'status',x.status,'name',pr.full_name,
   'decline_reason',case when public._console_federation_scope(o.sport_code,o.city_code,array['referee_committee']) then x.decline_reason end) order by x.duty)
   from match_officials x left join profiles pr on pr.id=x.profile_id where x.match_id=m.id),'[]'::jsonb) as officials
 from org_matches m join organizations o on o.id=m.org_id
 left join org_participants h on h.id=m.home_id left join org_participants a on a.id=m.away_id
 left join official_match_facilities e on e.match_id=m.id left join facilities f on f.id=e.facility_id
 where o.official and public._console_federation_scope(o.sport_code,o.city_code,array['provincial_rep','referee_committee','disciplinary_board'])
  and (p_city is null or o.city_code=p_city)
  and (p_from is null or m.starts_at>=p_from) and (p_until is null or m.starts_at<p_until)
  and (public.tr_contains(o.name,left(p_search,100)) or public.tr_contains(h.name,left(p_search,100)) or public.tr_contains(a.name,left(p_search,100))))
 select jsonb_build_object('total', (select count(*) from scoped),'rows',coalesce((
 select jsonb_agg(to_jsonb(page)) from (select * from scoped order by starts_at nulls last,id limit 50 offset greatest(coalesce(p_offset,0),0)) page),'[]'::jsonb))
$$;

create or replace function public.federation_available_referees(p_match_id uuid,p_city text default null)
returns table(profile_id uuid,name text,badge_tier text,city_code text,last_match_at timestamptz)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare o organizations;
begin
 select org.* into o from organizations org join org_matches m on m.org_id=org.id where m.id=p_match_id and org.official;
 if o.id is null or not public._console_federation_scope(o.sport_code,o.city_code,array['referee_committee']) then
  raise exception 'Başkan/MHK branş yetkisi gerekli' using errcode='42501'; end if;
 return query select r.profile_id,p.full_name,r.badge_tier,r.city_code,
  (select max(m.starts_at) from match_officials x join org_matches m on m.id=x.match_id
    where x.profile_id=r.profile_id and x.status='accepted' and m.status='played' and m.starts_at<=clock_timestamp())
 from referee_profiles r join profiles p on p.id=r.profile_id
 where r.is_active and r.sport_code=o.sport_code and (p_city is null or r.city_code=p_city) order by p.full_name,r.profile_id;
end $$;

create or replace function public.assign_match_official(p_match_id uuid,p_profile_id uuid,p_duty text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare m org_matches;o organizations;r referee_profiles;x match_officials;v uuid;
begin
 if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
 perform 1 from profiles where id=auth.uid() for key share;
 perform pg_advisory_xact_lock(113,0);
 perform pg_advisory_xact_lock(110,hashtext(p_match_id::text));
 select * into m from org_matches where id=p_match_id for update;
 select * into o from organizations where id=m.org_id and official;
 perform 1 from federation_roles fr join federations f on f.id=fr.federation_id
  where fr.profile_id=auth.uid() and f.sport_code=o.sport_code and fr.role in ('president','referee_committee') for share of fr;
 if o.id is null or not public._console_federation_scope(o.sport_code,o.city_code,array['referee_committee']) then
  raise exception 'Başkan/MHK branş yetkisi gerekli' using errcode='42501'; end if;
 if m.status<>'scheduled' or m.result_version<>0 or exists(select 1 from match_lineup_approvals where match_id=m.id) then
  raise exception 'Esame kilitli veya maç kapalı' using errcode='55000'; end if;
 if p_duty is null or p_duty not in ('head_referee','assistant_referee_1','assistant_referee_2','fourth_referee','table_official','observer') then
  raise exception 'Görev geçersiz' using errcode='22023'; end if;
 select * into r from referee_profiles where profile_id=p_profile_id for share;
 if r.id is null or not r.is_active or r.sport_code<>o.sport_code then raise exception 'Aktif aynı branş hakem lisansı gerekli' using errcode='22023'; end if;
 select * into x from match_officials where match_id=m.id and duty=p_duty for update;
 if x.profile_id=p_profile_id and x.status in ('assigned','accepted') then return x.id; end if;
 if exists(select 1 from match_officials where match_id=m.id and profile_id=p_profile_id and duty<>p_duty and status in ('assigned','accepted')) then
  raise exception 'Hakem aynı maçta ikinci göreve atanamaz' using errcode='22023'; end if;
 insert into match_officials(match_id,profile_id,duty,status,assigned_by) values(m.id,p_profile_id,p_duty,'assigned',auth.uid())
 on conflict(match_id,duty) do update set profile_id=excluded.profile_id,status='assigned',decline_reason=null,
  responded_at=null,assigned_at=clock_timestamp(),assigned_by=auth.uid() returning id into v;
 insert into federation_audit(actor_id,action,entity_id,detail) values(auth.uid(),'match_official_assigned',v,
  jsonb_build_object('match_id',m.id,'previous_profile_id',x.profile_id,'profile_id',p_profile_id,'duty',p_duty));
 return v;
end $$;

create table if not exists public.disciplinary_decisions (
 id uuid primary key default gen_random_uuid(),operation_id uuid not null unique,
 match_id uuid not null references public.org_matches(id) on delete restrict,
 sport_code text not null references public.sports(code),club_id uuid not null,
 athlete_id uuid not null, -- historical sporting UUID, no cascade/name snapshot
 penalty_type text not null check(penalty_type in ('match_ban','rights_ban','warning','fine')),
 match_ban_count int,months int,fine_amount numeric,
 reason text not null check(length(trim(reason)) between 1 and 1000),
 actor_id uuid references public.profiles(id) on delete set null,
 created_at timestamptz not null default clock_timestamp(),ends_at timestamptz,
 check(case penalty_type when 'match_ban' then coalesce(match_ban_count between 1 and 10,false) and months is null and fine_amount is null
  when 'rights_ban' then coalesce(months between 1 and 12,false) and ends_at is not null and match_ban_count is null and fine_amount is null
  when 'fine' then coalesce(fine_amount between 0.01 and 100000000,false) and months is null and match_ban_count is null
  else months is null and match_ban_count is null and fine_amount is null end));
create index if not exists disciplinary_athlete_sport on public.disciplinary_decisions(athlete_id,sport_code);
alter table public.disciplinary_decisions enable row level security;
revoke all on public.disciplinary_decisions from public,anon,authenticated;

create or replace function public._disciplinary_suspended(p_athlete uuid,p_sport text)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from disciplinary_decisions d where d.athlete_id=p_athlete and d.sport_code=p_sport and (
  (d.penalty_type='rights_ban' and d.ends_at>clock_timestamp()) or (d.penalty_type='match_ban' and d.match_ban_count>(
   select count(*) from org_matches m join organizations o on o.id=m.org_id
    where o.official and o.sport_code=d.sport_code and m.status='played'
     and m.starts_at>d.created_at and m.starts_at<=clock_timestamp()
     and exists(select 1 from referee_match_reports r where r.match_id=m.id and r.signed_at>d.created_at)
     and exists(select 1 from org_participants p where p.id in(m.home_id,m.away_id) and p.club_id=d.club_id)
     and not exists(select 1 from match_lineup_approvals la where la.match_id=m.id and p_athlete=any(la.starter_athlete_ids||la.substitute_athlete_ids))))))
$$;

create or replace function public.federation_disciplinary_reports(p_offset int default 0)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 with scoped as (select r.match_id,r.revision_id,r.signed_at,r.notes,o.name as program,o.sport_code,o.city_code,
  coalesce((select jsonb_agg(jsonb_build_object('athlete_id',a.id,'club_id',a.club_id,'reference',public.athlete_ref(a.id)))
   from athletes a where exists(select 1 from match_lineup_approvals la where la.match_id=m.id and a.id=any(la.starter_athlete_ids||la.substitute_athlete_ids))),'[]'::jsonb) as athletes,
  coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'side',e.side,'athlete_id',e.athlete_id,'card',e.card)) from match_live_events e
   where e.match_id=m.id and e.kind='card' and e.card='red' and not exists(select 1 from match_live_events u where u.undo_event_id=e.id)),'[]'::jsonb) as red_cards,
  coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'athlete_id',d.athlete_id,'penalty_type',d.penalty_type,'reason',d.reason,
   'match_ban_count',d.match_ban_count,'months',d.months,'fine_amount',d.fine_amount,'created_at',d.created_at)) from disciplinary_decisions d where d.match_id=m.id),'[]'::jsonb) as decisions,
  public._console_federation_scope(o.sport_code,o.city_code,array['disciplinary_board']) as can_decide
 from referee_match_reports r join org_matches m on m.id=r.match_id join organizations o on o.id=m.org_id
 where o.official and public._console_federation_scope(o.sport_code,o.city_code,array['referee_committee','disciplinary_board']))
 select jsonb_build_object('total',(select count(*) from scoped),'rows',coalesce((select jsonb_agg(to_jsonb(page)) from
  (select * from scoped order by signed_at,match_id limit 50 offset greatest(coalesce(p_offset,0),0)) page),'[]'::jsonb))
$$;

create or replace function public.record_disciplinary_decision(p_match_id uuid,p_athlete_id uuid,p_operation_id uuid,
 p_penalty_type text,p_reason text,p_match_ban_count int default null,p_months int default null,p_fine_amount numeric default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare o organizations;d disciplinary_decisions;c uuid;v uuid;
begin
 if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
 perform 1 from profiles where id=auth.uid() for key share;
 perform pg_advisory_xact_lock(113,0);
 select org.* into o from organizations org join org_matches m on m.org_id=org.id where m.id=p_match_id and org.official;
 perform 1 from federation_roles fr join federations f on f.id=fr.federation_id
  where fr.profile_id=auth.uid() and f.sport_code=o.sport_code and fr.role in ('president','disciplinary_board') for share of fr;
 if o.id is null or not public._console_federation_scope(o.sport_code,o.city_code,array['disciplinary_board']) then
  raise exception 'Başkan/Disiplin Kurulu branş yetkisi gerekli' using errcode='42501'; end if;
 select * into d from disciplinary_decisions where operation_id=p_operation_id;
 if found then
  if d.actor_id=auth.uid() and d.match_id=p_match_id and d.athlete_id=p_athlete_id and d.penalty_type=p_penalty_type
    and d.reason=trim(p_reason) and d.match_ban_count is not distinct from p_match_ban_count
    and d.months is not distinct from p_months and d.fine_amount is not distinct from p_fine_amount then return d.id; end if;
  raise exception 'İşlem kimliği farklı karar için kullanılmış' using errcode='22023'; end if;
 if not exists(select 1 from referee_match_reports where match_id=p_match_id) then raise exception 'İmzalı rapor gerekli' using errcode='55000'; end if;
 select a.club_id into c from athletes a where a.id=p_athlete_id and exists(select 1 from match_lineup_approvals la
  join org_participants p on p.id=la.participant_id where la.match_id=p_match_id and p.club_id=a.club_id and a.id=any(la.starter_athlete_ids||la.substitute_athlete_ids));
 if c is null then raise exception 'Sporcu kilitli maç esamesinde olmalı' using errcode='22023'; end if;
 if exists(select 1 from disciplinary_decisions where match_id=p_match_id and athlete_id=p_athlete_id) then
  raise exception 'Bu dosya/sporcu için karar zaten kayıtlı' using errcode='55000'; end if;
 insert into disciplinary_decisions(operation_id,match_id,sport_code,club_id,athlete_id,penalty_type,reason,match_ban_count,months,fine_amount,actor_id,ends_at)
 values(p_operation_id,p_match_id,o.sport_code,c,p_athlete_id,p_penalty_type,trim(p_reason),p_match_ban_count,p_months,p_fine_amount,auth.uid(),
  case when p_penalty_type='rights_ban' then clock_timestamp()+make_interval(months=>p_months) end) returning id into v;
 insert into federation_audit(actor_id,action,entity_id,detail) values(auth.uid(),'disciplinary_decision',v,
  jsonb_build_object('match_id',p_match_id,'athlete_id',p_athlete_id,'penalty_type',p_penalty_type));
 return v;
end $$;

create or replace function public.federation_locked_match_report(p_match_id uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 select jsonb_build_object('match_id',m.id,'revision_id',r.revision_id,'notes',r.notes,'signed_at',r.signed_at,
  'home_score',m.home_score,'away_score',m.away_score,
  'red_card_count',(select count(*) from match_live_events e where e.match_id=m.id and e.kind='card' and e.card='red'
   and not exists(select 1 from match_live_events u where u.undo_event_id=e.id)))
 from referee_match_reports r join org_matches m on m.id=r.match_id join organizations o on o.id=m.org_id
 where m.id=p_match_id and o.official and public._console_federation_scope(o.sport_code,o.city_code,array['referee_committee','disciplinary_board'])
$$;

-- Serialize decisions with esame/event/report writes before the existing match
-- lock; insert the sanction check into the shared server roster validator.
do $$ declare def text;sig text;begin
 foreach sig in array array['public.referee_verify_lineup(uuid,uuid[],uuid[],text,uuid[],uuid[])',
  'public.referee_append_match_event(uuid,uuid,integer,text,text,uuid,uuid,text)',
  'public.referee_submit_match_report(uuid,uuid,integer,text)'] loop
  def:=pg_get_functiondef(sig::regprocedure);
  if position('pg_advisory_xact_lock(113,0)' in def)=0 then
   if position('perform pg_advisory_xact_lock(110,' in def)=0 then raise exception 'Match lock contract changed'; end if;
   def:=replace(def,'perform pg_advisory_xact_lock(110,','perform pg_advisory_xact_lock(113,0); perform pg_advisory_xact_lock(110,');execute def;
  end if;
 end loop;
 def:=pg_get_functiondef('public._sports_roster_validate(uuid,uuid[],uuid[])'::regprocedure);
 if position('_disciplinary_suspended' in def)=0 then
  if position('perform public._c1_require_athlete' in def)=0 then raise exception 'Roster validation contract changed'; end if;
  def:=replace(def,'perform public._c1_require_athlete',
   'if public._disciplinary_suspended(a,o.sport_code) then raise exception ''Sporcu suspended: disiplin cezası aktif'' using errcode=''22023''; end if; perform public._c1_require_athlete');execute def;
 end if;
 def:=pg_get_functiondef('public.referee_lineup_candidates(uuid)'::regprocedure);
 if position('_disciplinary_suspended' in def)=0 then
  if position('case when exists(select 1 from public.eligibility_gate(a.id)' in def)=0 then raise exception 'Candidate contract changed'; end if;
  def:=replace(def,'case when exists(select 1 from public.eligibility_gate(a.id)',
   'case when public._disciplinary_suspended(a.id,o.sport_code) then ''suspended'' when exists(select 1 from public.eligibility_gate(a.id)');
  def:=replace(def,'not exists(select 1 from public.eligibility_gate(a.id)',
   'not public._disciplinary_suspended(a.id,o.sport_code) and not exists(select 1 from public.eligibility_gate(a.id)');execute def;
 end if;
 def:=pg_get_functiondef('public.referee_append_match_event(uuid,uuid,integer,text,text,uuid,uuid,text)'::regprocedure);
 if position('_disciplinary_suspended' in def)=0 then
  def:=replace(def,'or exists(select 1 from public.eligibility_gate(p_replacement_id)',
   'or public._disciplinary_suspended(p_replacement_id,st->>''sport_code'') or exists(select 1 from public.eligibility_gate(p_replacement_id)');execute def;
 end if;
 def:=pg_get_functiondef('public._notify_referee_assignment()'::regprocedure);
 if position('new.profile_id::text' in def)=0 then
  def:=replace(def,'(to_jsonb(old)->>''status'') is distinct from ''assigned''',
   '(to_jsonb(old)->>''status'') is distinct from ''assigned'' or (to_jsonb(old)->>''profile_id'') is distinct from new.profile_id::text');execute def;
 end if;
end $$;

drop trigger if exists disciplinary_decision_immutable on public.disciplinary_decisions;
create trigger disciplinary_decision_immutable before update or delete on public.disciplinary_decisions
 for each row execute function public._referee_journal_immutable();

revoke all on function public._console_federation_scope(text,text,text[]),public._disciplinary_suspended(uuid,text) from public,anon,authenticated;
revoke all on function public.allocate_official_match_facility(uuid,uuid,timestamptz),public.federation_console_scopes(),public.federation_console_matches(text,int,text,timestamptz,timestamptz),
 public.federation_available_referees(uuid,text),public.assign_match_official(uuid,uuid,text),
 public.federation_disciplinary_reports(int),public.federation_locked_match_report(uuid),public.record_disciplinary_decision(uuid,uuid,uuid,text,text,int,int,numeric) from public,anon;
grant execute on function public.allocate_official_match_facility(uuid,uuid,timestamptz),public.federation_console_scopes(),public.federation_console_matches(text,int,text,timestamptz,timestamptz),
 public.federation_available_referees(uuid,text),public.assign_match_official(uuid,uuid,text),
 public.federation_disciplinary_reports(int),public.federation_locked_match_report(uuid),public.record_disciplinary_decision(uuid,uuid,uuid,text,text,int,int,numeric) to authenticated;

insert into public.faq_entries(question,answer,category,audience,sort_order)
 select 'Federasyon konsolunda hakem ve disiplin işlemlerini kim yönetir?',
 'Aktif Başkan ve MHK aynı branşta hakem atar. İl temsilcisi yalnız kendi ilini ve atama durumlarını görür; özel ret notunu göremez. İmzalı raporlar Başkan, MHK ve Disiplin Kuruluna açıktır. Ceza kararını Başkan veya Disiplin Kurulu verir. Aktif maç men ve hak mahrumiyeti cezaları yeni esame onayında sunucuda denetlenir. İhtar ve para cezası esameyi kilitlemez.',
 'genel','everyone',113 where not exists(select 1 from public.faq_entries where question='Federasyon konsolunda hakem ve disiplin işlemlerini kim yönetir?');
