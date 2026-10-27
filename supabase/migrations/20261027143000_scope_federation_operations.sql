set local lock_timeout = '15s';

-- Keep federation selection authoritative all the way through pagination.
-- The legacy helper is sport/city scoped, so this companion also binds the
-- caller to the exact federation returned by federation_console_scopes().
create or replace function public._console_federation_scope_exact(
 p_federation_id uuid,p_sport text,p_city text,p_roles text[])
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and exists (
  select 1 from federation_roles r join federations f on f.id=r.federation_id
  where r.profile_id=auth.uid() and r.federation_id=p_federation_id
   and f.sport_code=p_sport and r.revoked_at is null
   and (clock_timestamp() at time zone 'Europe/Istanbul')::date between r.starts_on and r.ends_on
   and (r.role='president' or (r.role=any(p_roles)
    and (r.role<>'provincial_rep' or r.city_code=p_city))))
$$;

drop function if exists public.federation_console_matches(text,int,text,timestamptz,timestamptz);
create or replace function public.federation_console_matches(
 p_city text default null,p_offset int default 0,p_search text default '',
 p_from timestamptz default null,p_until timestamptz default null,
 p_federation_id uuid default null,p_sport_code text default null)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 with scoped as (
 select m.id,o.name as program,o.sport_code,o.city_code,m.starts_at,m.location,m.status,
  h.name as home_name,a.name as away_name,f.name as facility_name,
  exists(select 1 from org_participants participant
   where participant.id in(m.home_id,m.away_id) and participant.club_id is not null
    and public.is_club_staff(participant.club_id)) as can_allocate_facility,
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
   'decline_reason',case when public._console_federation_scope_exact(fo.federation_id,o.sport_code,o.city_code,array['referee_committee']) then x.decline_reason end) order by x.duty)
   from match_officials x left join profiles pr on pr.id=x.profile_id where x.match_id=m.id),'[]'::jsonb) as officials
 from org_matches m join organizations o on o.id=m.org_id
 join federation_offices fo on fo.id=o.federation_office_id
 left join org_participants h on h.id=m.home_id left join org_participants a on a.id=m.away_id
 left join official_match_facilities e on e.match_id=m.id left join facilities f on f.id=e.facility_id
 where o.official
  and case when p_federation_id is null
   then public._console_federation_scope(o.sport_code,o.city_code,array['provincial_rep','referee_committee','disciplinary_board'])
   else public._console_federation_scope_exact(p_federation_id,o.sport_code,o.city_code,array['provincial_rep','referee_committee','disciplinary_board']) end
  and (p_federation_id is null or fo.federation_id=p_federation_id)
  and (p_sport_code is null or o.sport_code=p_sport_code)
  and (p_city is null or o.city_code=p_city)
  and (p_from is null or m.starts_at>=p_from) and (p_until is null or m.starts_at<p_until)
  and (public.tr_contains(o.name,left(p_search,100)) or public.tr_contains(h.name,left(p_search,100)) or public.tr_contains(a.name,left(p_search,100))))
 select jsonb_build_object('total',(select count(*) from scoped),'rows',coalesce((
  select jsonb_agg(to_jsonb(page)) from (select * from scoped order by starts_at nulls last,id
   limit 50 offset greatest(coalesce(p_offset,0),0)) page),'[]'::jsonb))
$$;

drop function if exists public.federation_disciplinary_reports(int);
create or replace function public.federation_disciplinary_reports(
 p_offset int default 0,p_federation_id uuid default null,p_sport_code text default null)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
 with scoped as (select r.match_id,r.revision_id,r.signed_at,r.notes,o.name as program,o.sport_code,o.city_code,
  coalesce((select jsonb_agg(jsonb_build_object('athlete_id',a.id,'club_id',a.club_id,'reference',public.athlete_ref(a.id)))
   from athletes a where exists(select 1 from match_lineup_approvals la where la.match_id=m.id and a.id=any(la.starter_athlete_ids||la.substitute_athlete_ids))),'[]'::jsonb) as athletes,
  coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'side',e.side,'athlete_id',e.athlete_id,'card',e.card)) from match_live_events e
   where e.match_id=m.id and e.kind='card' and e.card='red' and not exists(select 1 from match_live_events u where u.undo_event_id=e.id)),'[]'::jsonb) as red_cards,
  coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'athlete_id',d.athlete_id,'penalty_type',d.penalty_type,'reason',d.reason,
   'match_ban_count',d.match_ban_count,'months',d.months,'fine_amount',d.fine_amount,'created_at',d.created_at)) from disciplinary_decisions d where d.match_id=m.id),'[]'::jsonb) as decisions,
  public._console_federation_scope_exact(fo.federation_id,o.sport_code,o.city_code,array['disciplinary_board']) as can_decide
 from referee_match_reports r join org_matches m on m.id=r.match_id join organizations o on o.id=m.org_id
 join federation_offices fo on fo.id=o.federation_office_id
 where o.official
  and case when p_federation_id is null
   then public._console_federation_scope(o.sport_code,o.city_code,array['referee_committee','disciplinary_board'])
   else public._console_federation_scope_exact(p_federation_id,o.sport_code,o.city_code,array['referee_committee','disciplinary_board']) end
  and (p_federation_id is null or fo.federation_id=p_federation_id)
  and (p_sport_code is null or o.sport_code=p_sport_code))
 select jsonb_build_object('total',(select count(*) from scoped),'rows',coalesce((select jsonb_agg(to_jsonb(page)) from
  (select * from scoped order by signed_at,match_id limit 50 offset greatest(coalesce(p_offset,0),0)) page),'[]'::jsonb))
$$;

drop function if exists public.federation_pending_results(int,int);
create or replace function public.federation_pending_results(
 p_offset int default 0,p_limit int default 100,p_federation_id uuid default null,
 p_sport_code text default null,p_city text default null)
returns table(match_id uuid,org_name text,sport_code text,city_code text,starts_at timestamptz,location text,
 home_name text,away_name text,version int)
language sql stable security definer set search_path=public,pg_temp as $$
 select m.id,o.name,o.sport_code,o.city_code,m.starts_at,m.location,h.legal_name,a.legal_name,m.result_version
 from public.org_matches m join public.organizations o on o.id=m.org_id and o.official
 join public.federation_offices organization_office on organization_office.id=o.federation_office_id
 left join public.org_participants hp on hp.id=m.home_id left join public.clubs h on h.id=hp.club_id
 left join public.org_participants ap on ap.id=m.away_id left join public.clubs a on a.id=ap.club_id
 where m.status='scheduled' and m.result_version=0
  and (p_federation_id is null or organization_office.federation_id=p_federation_id)
  and (p_sport_code is null or o.sport_code=p_sport_code)
  and (p_city is null or o.city_code=p_city)
  and exists(select 1 from public.federation_appointments fa
   join public.federation_offices appointment_office on appointment_office.id=fa.office_id
   join public.federations federation on federation.id=appointment_office.federation_id
   where fa.profile_id=auth.uid() and fa.duty='result_publisher' and fa.revoked_at is null
    and (now() at time zone 'Europe/Istanbul')::date between fa.starts_on and fa.ends_on
    and federation.sport_code=o.sport_code
    and appointment_office.federation_id=organization_office.federation_id
    and (appointment_office.city_code is null or appointment_office.city_code=o.city_code))
 order by m.starts_at nulls last,m.id limit least(greatest(p_limit,1),100) offset greatest(p_offset,0)
$$;

revoke all on function public._console_federation_scope_exact(uuid,text,text,text[]) from public,anon,authenticated;
revoke all on function public.federation_console_matches(text,int,text,timestamptz,timestamptz,uuid,text),
 public.federation_disciplinary_reports(int,uuid,text),
 public.federation_pending_results(int,int,uuid,text,text) from public,anon;
grant execute on function public.federation_console_matches(text,int,text,timestamptz,timestamptz,uuid,text),
 public.federation_disciplinary_reports(int,uuid,text),
 public.federation_pending_results(int,int,uuid,text,text) to authenticated;
