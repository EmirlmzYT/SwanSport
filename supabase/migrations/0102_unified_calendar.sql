set local lock_timeout = '15s';

-- Published public metadata only. Existing publication and result RPCs unchanged.
create or replace function public.public_federation_activities(
 p_sport text default null,p_city text default null,p_season uuid default null,
 p_from date default null,p_to date default null)
returns table(id uuid,program_id uuid,is_match boolean,federation_name text,
 office_name text,season_id uuid,season_label text,sport_code text,city_code text,
 title text,kind text,category text,location text,status text,
 starts_at timestamptz,ends_at timestamptz,all_day boolean)
language sql stable security definer set search_path=public as $$
 with programs as (
  select o.id,o.name,o.kind,o.sport_code,o.city_code,o.age_group,o.location,o.status,
   coalesce(o.starts_on,s.starts_on) starts_on,coalesce(o.ends_on,s.ends_on) ends_on,
   s.id season_id,s.label season_label,f.name federation_name,fo.name office_name
  from public.organizations o join public.sport_seasons s on s.id=o.sport_season_id
  join public.federation_offices fo on fo.id=o.federation_office_id and s.office_id=fo.id
  join public.federations f on f.id=fo.federation_id and f.sport_code=o.sport_code
  where o.official and o.is_public
   and (fo.city_code is null or fo.city_code=o.city_code)
   and (p_sport is null or o.sport_code=p_sport)
   and (p_city is null or o.city_code is null or o.city_code=p_city)
   and (p_season is null or s.id=p_season)
 ), entries as (
  select p.id,p.id program_id,false is_match,p.federation_name,p.office_name,
   p.season_id,p.season_label,p.sport_code,p.city_code,p.name title,p.kind,
   p.age_group category,p.location,p.status,
   p.starts_on::timestamp at time zone 'Europe/Istanbul' starts_at,
   (p.ends_on+1)::timestamp at time zone 'Europe/Istanbul' ends_at,true all_day
  from programs p
  union all
  select m.id,p.id,true,p.federation_name,p.office_name,p.season_id,p.season_label,
   p.sport_code,p.city_code,
   concat(p.name,' · ',coalesce(h.name,'Ev sahibi'),' – ',coalesce(a.name,'Deplasman')),
   'match',p.age_group,m.location,m.status,m.starts_at,null::timestamptz,false
  from programs p join public.org_matches m on m.org_id=p.id
  left join public.org_participants h on h.id=m.home_id and h.org_id=p.id
  left join public.org_participants a on a.id=m.away_id and a.org_id=p.id
  where m.starts_at is not null
 )
 select e.id,e.program_id,e.is_match,e.federation_name,e.office_name,e.season_id,
  e.season_label,e.sport_code,e.city_code,e.title,e.kind,e.category,e.location,
  e.status,e.starts_at,e.ends_at,e.all_day from entries e
 where (p_from is null or e.starts_at>=p_from::timestamp at time zone 'Europe/Istanbul'
   or e.ends_at>p_from::timestamp at time zone 'Europe/Istanbul')
  and (p_to is null or e.starts_at<p_to::timestamp at time zone 'Europe/Istanbul')
 order by e.starts_at,e.is_match,e.id
$$;
revoke all on function public.public_federation_activities(text,text,uuid,date,date) from public,anon,authenticated;
grant execute on function public.public_federation_activities(text,text,uuid,date,date) to anon,authenticated;

-- No platform admin bypass, accountant path or athlete-name projection.
create or replace function public._calendar_team_visible(p_club uuid,p_team uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select auth.uid() is not null and (
  exists(select 1 from public.club_memberships cm where cm.club_id=p_club
   and cm.profile_id=auth.uid() and cm.status='active' and cm.role::text<>'parent')
  or exists(select 1 from public.guardians g join public.athletes a on a.id=g.athlete_id
   where g.profile_id=auth.uid() and a.club_id=p_club and
   (p_team is null or exists(select 1 from public.team_memberships tm
     join public.teams t on t.id=tm.team_id and t.club_id=p_club
     where tm.athlete_id=a.id and tm.team_id=p_team))))
$$;
revoke all on function public._calendar_team_visible(uuid,uuid) from public,anon,authenticated;

create or replace function public.my_calendar_club_entries(
 p_from timestamptz,p_to timestamptz,p_club uuid default null)
returns table(id uuid,club_id uuid,event_id uuid,session_id uuid,title text,
 kind text,starts_at timestamptz,ends_at timestamptz,place text,status text,
 opponent text,home_score int,away_score int,team_id uuid)
language plpgsql stable security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Oturum gerekli' using errcode='42501'; end if;
 if p_from is null or p_to is null or p_to<=p_from or p_to-p_from>interval '370 days' then
  raise exception 'Geçerli, en fazla 370 günlük aralık gerekli'; end if;
 return query
 with visible_events as (
  select e.id,e.club_id,e.title,e.kind::text kind,e.starts_at,e.ends_at,e.place,
   e.opponent,e.home_score,e.away_score,e.team_id
  from public.events e where (p_club is null or e.club_id=p_club)
   and public._calendar_team_visible(e.club_id,e.team_id)
   and e.starts_at<p_to and (e.starts_at>=p_from or e.ends_at>p_from)
 )
 select e.id,e.club_id,e.id,s.id,e.title,e.kind,e.starts_at,e.ends_at,e.place,
  coalesce(s.status,'scheduled'),e.opponent,e.home_score,e.away_score,e.team_id
 from visible_events e left join lateral (
  select ts.id,ts.status from public.training_sessions ts
  where ts.event_id=e.id and ts.club_id=e.club_id and ts.kind='club'
   and public._calendar_team_visible(ts.club_id,ts.team_id)
  order by ts.started_at desc,ts.id limit 1
 ) s on true
 union all
 select ts.id,ts.club_id,ts.event_id,ts.id,coalesce(tp.name,'Antrenman'),
  'training',ts.started_at,ts.ended_at,null::text,ts.status,
  null::text,null::int,null::int,ts.team_id
 from public.training_sessions ts join public.training_protocols tp on tp.id=ts.protocol_id
 where ts.kind='club' and (p_club is null or ts.club_id=p_club)
  and public._calendar_team_visible(ts.club_id,ts.team_id)
  and ts.started_at<p_to and (ts.started_at>=p_from or ts.ended_at>p_from)
  and not exists(select 1 from visible_events ve where ve.id=ts.event_id)
  -- A linked hidden-team event must not be disclosed through its session.
  and (ts.event_id is null or exists(select 1 from public.events linked
    where linked.id=ts.event_id and linked.club_id=ts.club_id
     and public._calendar_team_visible(linked.club_id,linked.team_id)))
 order by 7,1;
end $$;
revoke all on function public.my_calendar_club_entries(timestamptz,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.my_calendar_club_entries(timestamptz,timestamptz,uuid) to authenticated;

insert into public.faq_entries(question,answer,category,audience,sort_order,route)
select 'Birleşik Takvim hangi kayıtları gösterir?',
 'Birleşik Takvim yayımlanmış resmi federasyon faaliyetlerini ve müsabakaları, hesabının erişebildiği kulüp etkinlikleri ve antrenman oturumlarıyla birlikte gösterir. Misafirler yalnız resmi yayımlanmış kayıtları görür. Veli, bağlı çocuğunun kulübü ve takımı kapsamındaki kayıtları görür. Tümü, Kulüp Antrenmanları ve Resmi Federasyon Faaliyetleri sekmeleriyle süzebilirsin. Çok günlü faaliyetler devam ettiği her gün görünür; resmi faaliyetler bu ekrandan düzenlenmez.',
 'Genel','everyone',102,'/calendar'
where not exists(select 1 from public.faq_entries where question='Birleşik Takvim hangi kayıtları gösterir?');
