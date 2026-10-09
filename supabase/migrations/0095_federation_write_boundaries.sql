-- Phase A: protect old RPC/direct-write paths as well as the new RPC surface.
set local lock_timeout = '15s';

do $$ declare t text;begin
 foreach t in array array['organizations','org_matches','org_participants','athlete_achievements','clubs','athletes'] loop
 execute format('drop trigger if exists federation_guard on public.%I',t); end loop;
end $$;
drop function if exists public._federation_guard();
create function public._federation_guard() returns trigger language plpgsql security definer set search_path=public as $$
declare o public.organizations; v_sport text; v_city text; v_duty text; v_appointment uuid; v_entity uuid;
begin
 if tg_table_name='organizations' then
  if tg_op='DELETE' then
   if old.official then raise exception 'Resmi geçmiş silinemez'; end if;
   return old;
  end if;
  if tg_op='UPDATE' and old.official then
   if not new.official or (new.federation_office_id,new.sport_code,new.city_code,new.sport_season_id)
     is distinct from (old.federation_office_id,old.sport_code,old.city_code,old.sport_season_id) then
    raise exception 'Resmi sahip/branş/il değiştirilemez'; end if;
  end if;
  if not new.official then return new; end if;
  select * into o from public.organizations where id=new.id;
  v_sport:=new.sport_code; v_city:=new.city_code; v_duty:='program_publisher'; v_entity:=new.id;
  if not exists(select 1 from public.federation_offices f join public.federations x on x.id=f.federation_id
    join public.sport_seasons s on s.office_id=f.id
    where f.id=new.federation_office_id and x.sport_code=new.sport_code
    and s.id=new.sport_season_id and (f.city_code is null or f.city_code=new.city_code)
    and new.starts_on>=s.starts_on and new.ends_on<=s.ends_on and new.ends_on>=new.starts_on) then
   raise exception 'Faaliyet yılı/branş/il/tarih uyuşmuyor'; end if;
 elsif tg_table_name in ('org_matches','org_participants') then
  if tg_op='INSERT' then select * into o from public.organizations where id=new.org_id for share;
  else select * into o from public.organizations where id=old.org_id for share; end if;
  if tg_op='UPDATE' and new.org_id is distinct from old.org_id then
   if o.official or exists(select 1 from public.organizations where id=new.org_id and official) then
    raise exception 'Resmi kayıt taşınamaz'; end if;
  end if;
  if not coalesce(o.official,false) then
   if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op='DELETE' then raise exception 'Resmi geçmiş silinemez'; end if;
  -- Referential SET NULL only: club/team deletion must not erase the fixture or roster.
  if tg_table_name='org_participants' then
   if tg_op='UPDATE' and pg_trigger_depth()>1
    and (to_jsonb(new)-'club_id'-'team_id')=(to_jsonb(old)-'club_id'-'team_id')
    and (new.club_id is not distinct from old.club_id or new.club_id is null)
    and (new.team_id is not distinct from old.team_id or new.team_id is null) then return new; end if;
  end if;
  v_sport:=o.sport_code; v_city:=o.city_code; v_entity:=new.id; v_duty:='program_publisher';
  if tg_table_name='org_matches' then
   if new.event_id is not null then raise exception 'Resmi maç kulüp events kaydına kopyalanamaz'; end if;
   if tg_op='INSERT' and (new.result_protocol is not null or new.home_score is not null or new.away_score is not null or new.status='played' or new.result_version<>0) then
    raise exception 'Sonuç ayrı federasyon RPC ile yazılmalı'; end if;
   if tg_op='UPDATE' then
    if (new.result_protocol,new.home_score,new.away_score,new.status,new.result_version)
      is distinct from (old.result_protocol,old.home_score,old.away_score,old.status,old.result_version) then
     v_duty:='result_publisher';
     if (to_jsonb(new)-array['result_protocol','home_score','away_score','status','result_version'])
       is distinct from (to_jsonb(old)-array['result_protocol','home_score','away_score','status','result_version']) then
      raise exception 'Sonuç ve program aynı işlemde değiştirilemez'; end if;
     if new.result_version<>old.result_version+1 or not exists(select 1 from public.org_result_revisions r
       where r.match_id=new.id and r.version=new.result_version and r.protocol=new.result_protocol) then
      raise exception 'Sonuç revizyonu zorunlu'; end if;
    end if;
    if exists(select 1 from public.org_result_revisions r where r.match_id=old.id)
      and (new.home_id,new.away_id) is distinct from (old.home_id,old.away_id) then raise exception 'Sonuçlu maçın tarafları değiştirilemez'; end if;
   end if;
   if not exists(select 1 from public.org_participants where id=new.home_id and org_id=o.id and status='accepted')
    or (new.away_id is not null and not exists(select 1 from public.org_participants where id=new.away_id and org_id=o.id and status='accepted')) then
    raise exception 'Katılımcı aynı organizasyondan olmalı'; end if;
  else
   if tg_op='UPDATE' and exists(select 1 from public.org_roster_revisions r where r.participant_id=old.id) then
    raise exception 'Yayımlanmış katılımcı değiştirilemez; yeni kayıt gerekir'; end if;
   if not exists(select 1 from public.club_sport_registrations r join public.clubs c on c.id=r.club_id
    where r.club_id=new.club_id and r.sport_code=o.sport_code and c.registration_status='approved'
      and (o.city_code is null or c.registration_city_code=o.city_code) and new.name=c.legal_name) then
    raise exception 'Onaylı kulüp/branş/il ve yasal ad gerekli'; end if;
   if new.team_id is not null and not exists(select 1 from public.teams t where t.id=new.team_id and t.club_id=new.club_id and t.sport_code=o.sport_code) then
    raise exception 'Takım branşı veya kulübü yanlış'; end if;
  end if;
 elsif tg_table_name='athlete_achievements' then
  if tg_op='UPDATE' then
   if old.source='federation_result' and pg_trigger_depth()>1
    and (to_jsonb(new)-array['created_by','verified_by'])=(to_jsonb(old)-array['created_by','verified_by'])
    and (new.created_by is not distinct from old.created_by or new.created_by is null)
    and (new.verified_by is not distinct from old.verified_by or new.verified_by is null) then return new; end if;
  end if;
  if tg_op<>'INSERT' and old.source='federation_result' then raise exception 'Resmi derece yalnız yeni revizyonla düzeltilir'; end if;
  if tg_op='DELETE' then return old; end if;
  if new.source is distinct from 'federation_result' then
   if new.official_match_id is not null or new.supersedes_id is not null then raise exception 'Kulüp gelişimi resmi kaynak değildir'; end if;
   perform 1 from public.athletes where id=new.athlete_id for key share;
   if not found then raise exception 'Sporcu bulunamadı'; end if;
   return new;
  end if;
  select org.* into o from public.org_matches m join public.organizations org on org.id=m.org_id where m.id=new.official_match_id;
  if not coalesce(o.official,false) then raise exception 'Resmi maç zorunlu'; end if;
  if not exists(select 1 from public.org_result_revisions rv join public.org_roster_revisions r
    on r.id in(rv.home_roster_revision_id,rv.away_roster_revision_id)
    where rv.id=new.source_id and rv.match_id=new.official_match_id and new.athlete_id=any(r.athlete_ids)) then raise exception 'Sporcu resmi kadroda yok'; end if;
  if new.supersedes_id is not null and not exists(select 1 from public.athlete_achievements a where a.id=new.supersedes_id
    and a.source='federation_result' and a.athlete_id=new.athlete_id and a.official_match_id=new.official_match_id) then raise exception 'Derece revizyon kaynağı yanlış'; end if;
  v_sport:=o.sport_code;v_city:=o.city_code;v_duty:='result_publisher';v_entity:=new.id;
 elsif tg_table_name='clubs' then
  if tg_op='INSERT' then
   if new.registration_status='unregistered' and new.legal_name is null and new.registration_no is null and new.registration_city_code is null and new.registration_sport_code is null then return new; end if;
  elsif (new.legal_name,new.registration_no,new.registration_city_code,new.registration_status,new.registration_sport_code)
    is not distinct from(old.legal_name,old.registration_no,old.registration_city_code,old.registration_status,old.registration_sport_code) then
   if old.registration_status='approved' and new.sport_code is distinct from old.sport_code then raise exception 'Tescilli kulübün ana branşı değiştirilemez'; end if;
   return new;
  end if;
  select code into v_sport from public.sports where code=new.registration_sport_code;
  v_city:=new.registration_city_code;v_duty:='club_registrar';v_entity:=new.id;
  if tg_op='UPDATE' and old.registration_city_code is not null then
   perform public._federation_require(v_sport,old.registration_city_code,v_duty); end if;
 elsif tg_table_name='athletes' then
  if tg_op='INSERT' then
   if new.license_expires_on is null then return new; end if;
  elsif new.license_expires_on is not distinct from old.license_expires_on then return new; end if;
  select sport_code,registration_city_code into v_sport,v_city from public.clubs where id=new.club_id;
  v_duty:='license_registrar';v_entity:=new.id;
 end if;
 v_appointment:=public._federation_require(v_sport,v_city,v_duty);
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail)
 values(auth.uid(),v_appointment,tg_table_name||':'||tg_op,v_entity,jsonb_build_object('sport',v_sport,'city',v_city));
 return new;
end $$;
revoke all on function public._federation_guard() from public,anon,authenticated;
do $$ declare t text;begin
 foreach t in array array['organizations','org_matches','org_participants','athlete_achievements'] loop
 execute format('drop trigger if exists federation_guard on public.%I',t);
 execute format('create trigger federation_guard before insert or update or delete on public.%I for each row execute function public._federation_guard()',t);
 end loop;
 foreach t in array array['clubs','athletes'] loop
 execute format('drop trigger if exists federation_guard on public.%I',t);
 execute format('create trigger federation_guard before insert or update on public.%I for each row execute function public._federation_guard()',t);
 end loop;
end $$;

-- Legacy organization owners have no federated authority.
-- Same signature/return type; dependencies prohibit DROP without CASCADE, so REPLACE is intentional.
create or replace function public.is_org_owner(p_org uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.organizations o where o.id=p_org and not o.official
 and (o.owner_id=auth.uid() or (o.club_id is not null and public.is_club_staff(o.club_id))))
$$;

drop trigger if exists federation_credential_rules on public.profile_credentials;
drop trigger if exists federation_team_rules on public.teams;
drop trigger if exists federation_supervisor_rules on public.club_memberships;
drop function if exists public._federation_new_row_rules();
create function public._federation_new_row_rules() returns trigger language plpgsql security definer set search_path=public as $$
declare s text;
begin
 if tg_table_name='profile_credentials' then
  if tg_op='INSERT' and (new.expires_on is null or new.expires_on<current_date or new.sport_code is null) then
   raise exception 'Yeni belge için branş ve geçerli bitiş tarihi zorunlu'; end if;
  if tg_op='UPDATE' and old.expires_on is not null and new.expires_on is null then raise exception 'Belge süresi kaldırılamaz'; end if;
  if tg_op='INSERT' and not public.is_platform_admin() and (new.status<>'pending' or new.reviewed_at is not null or new.reviewed_by is not null) then
   raise exception 'Kendi belgeni onaylayamazsın'; end if;
 elsif tg_table_name='teams' then
  new.sport_code:=coalesce(new.sport_code,(select sport_code from public.clubs where id=new.club_id));
  if new.sport_code is null then raise exception 'Yeni takım için branş zorunlu'; end if;
 elsif tg_table_name='club_memberships' then
  if new.role='coach' and new.coach_level=1 then
   select coalesce(t.sport_code,c.sport_code) into s from public.clubs c left join public.teams t on t.id=new.team_id where c.id=new.club_id;
   if new.supervisor_id is null or new.supervisor_id=new.profile_id or not exists(select 1 from public.club_memberships m
    where m.club_id=new.club_id and m.profile_id=new.supervisor_id and m.role='coach' and m.status='active'
    and public.coach_level_for_sport(m.profile_id,s)>=2) then raise exception '1. kademe için aynı branşta aktif süpervizör zorunlu'; end if;
  end if;
 end if;
 return new;
end $$;
revoke all on function public._federation_new_row_rules() from public,anon,authenticated;
drop trigger if exists federation_credential_rules on public.profile_credentials;
create trigger federation_credential_rules before insert or update on public.profile_credentials for each row execute function public._federation_new_row_rules();
drop trigger if exists federation_team_rules on public.teams;
create trigger federation_team_rules before insert on public.teams for each row execute function public._federation_new_row_rules();
drop trigger if exists federation_supervisor_rules on public.club_memberships;
create trigger federation_supervisor_rules before insert on public.club_memberships for each row execute function public._federation_new_row_rules();

-- A club write policy cannot manufacture or delete a federation source.
drop policy if exists achv_write on public.athlete_achievements;
create policy achv_write on public.athlete_achievements for all to authenticated
 using(source is distinct from 'federation_result' and public.can_manage_athlete(athlete_id))
 with check(source is distinct from 'federation_result' and official_match_id is null and supersedes_id is null and public.can_manage_athlete(athlete_id));
-- New official source IDs are revision IDs, so the existing source uniqueness remains useful.
create unique index if not exists official_degree_successor on public.athlete_achievements(supersedes_id) where supersedes_id is not null;

drop trigger if exists delete_club_achievements on public.athletes;
drop function if exists public._delete_club_achievements();
create function public._delete_club_achievements() returns trigger language plpgsql security definer set search_path=public as $$
begin delete from public.athlete_achievements where athlete_id=old.id and source is distinct from 'federation_result';return old;end $$;
revoke all on function public._delete_club_achievements() from public,anon,authenticated;
drop trigger if exists delete_club_achievements on public.athletes;
create trigger delete_club_achievements after delete on public.athletes for each row execute function public._delete_club_achievements();
-- No anonymous access is introduced. Explicitly close reused official tables as well.
revoke all on public.organizations,public.org_participants,public.org_matches,public.athlete_achievements from anon;

-- Official degrees are available through the allowlisted federation card, not legacy public achievements reads.
drop policy if exists official_achievement_read_boundary on public.athlete_achievements;
create policy official_achievement_read_boundary on public.athlete_achievements as restrictive for select to authenticated
 using(source is distinct from 'federation_result');

-- Reused discovery APIs must not expose official UUIDs that can be joined to legacy public athlete views.
do $$ declare t text;begin
 foreach t in array array['organizations','org_participants','org_matches'] loop
  execute format('drop policy if exists federation_private_read on public.%I',t);
  if t='organizations' then
   execute 'create policy federation_private_read on public.organizations as restrictive for select to authenticated using(not official)';
  else
   execute format('create policy federation_private_read on public.%I as restrictive for select to authenticated using(exists(select 1 from public.organizations o where o.id=org_id and not o.official))',t);
  end if;
 end loop;
end $$;

drop function if exists public.org_standings(uuid);
create or replace function public.org_standings(p_org uuid)
returns table (
  participant_id uuid, name text, club_id uuid,
  played int, won int, drawn int, lost int,
  scored int, conceded int, diff int, points int
)
language sql stable security definer set search_path = public as $$
  with cfg as (select win_points w, draw_points d, loss_points l
                 from public.organizations where id = p_org),
  games as (
    select m.home_id as pid, m.home_score as gf, m.away_score as ga
      from public.org_matches m
     where m.org_id = p_org and m.status = 'played'
       and m.home_score is not null and m.away_score is not null
    union all
    select m.away_id, m.away_score, m.home_score
      from public.org_matches m
     where m.org_id = p_org and m.status = 'played'
       and m.home_score is not null and m.away_score is not null
  ),
  agg as (
    select g.pid,
           count(*)::int as played,
           count(*) filter (where g.gf > g.ga)::int as won,
           count(*) filter (where g.gf = g.ga)::int as drawn,
           count(*) filter (where g.gf < g.ga)::int as lost,
           coalesce(sum(g.gf), 0)::int as scored,
           coalesce(sum(g.ga), 0)::int as conceded
      from games g group by g.pid
  )
  select p.id, p.name, p.club_id,
         coalesce(a.played, 0), coalesce(a.won, 0), coalesce(a.drawn, 0),
         coalesce(a.lost, 0), coalesce(a.scored, 0), coalesce(a.conceded, 0),
         coalesce(a.scored, 0) - coalesce(a.conceded, 0),
         (coalesce(a.won,0) * (select w from cfg)
          + coalesce(a.drawn,0) * (select d from cfg)
          + coalesce(a.lost,0) * (select l from cfg))::int
    from public.org_participants p
    left join agg a on a.pid = p.id
   where p.org_id = p_org and p.status = 'accepted'
     and exists(select 1 from public.organizations x where x.id=p_org and not x.official)
   -- Sıralama: puan (11), averaj (10), atılan (8). Çıktı 11 sütun.
   order by 11 desc, 10 desc, 8 desc, p.name;
$$;

drop function if exists public.list_organizations(text,text,text,int);
create or replace function public.list_organizations(
  p_sport text default null, p_city text default null,
  p_kind text default null, p_limit int default 40)
returns table (
  id uuid, name text, kind text, sport_name text, city_name text,
  age_group text, starts_on date, ends_on date, status text,
  club_id uuid, club_name text, participant_count int, can_manage boolean
)
language sql stable security definer set search_path = public as $$
  select o.id, o.name, o.kind, s.name, ct.name, o.age_group,
         o.starts_on, o.ends_on, o.status, o.club_id, c.name,
         (select count(*) from public.org_participants p
           where p.org_id = o.id and p.status = 'accepted')::int,
         public.is_org_owner(o.id)
    from public.organizations o
    left join public.sports s on s.code = o.sport_code
    left join public.cities ct on ct.code = o.city_code
    left join public.clubs c on c.id = o.club_id
   where not o.official and (o.is_public or public.is_org_owner(o.id))
     and (p_sport is null or o.sport_code = p_sport)
     and (p_city is null or o.city_code = p_city)
     and (p_kind is null or o.kind = p_kind)
   order by (o.status <> 'finished') desc, o.starts_on desc nulls last
   limit greatest(p_limit, 1);
$$;

drop function if exists public.org_fixture(uuid);
create or replace function public.org_fixture(p_org uuid)
returns table (
  id uuid, round int, starts_at timestamptz, status text,
  home_id uuid, home_name text, away_id uuid, away_name text,
  home_score int, away_score int, can_manage boolean
)
language sql stable security definer set search_path = public as $$
  select m.id, m.round, m.starts_at, m.status,
         m.home_id, h.name, m.away_id, a.name,
         m.home_score, m.away_score, public.is_org_owner(m.org_id)
    from public.org_matches m
    left join public.org_participants h on h.id = m.home_id
    left join public.org_participants a on a.id = m.away_id
   where m.org_id = p_org and exists(select 1 from public.organizations x where x.id=p_org and not x.official)
   order by m.round, m.starts_at;
$$;

do $$ declare r record;begin
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('org_fixture','org_standings','list_organizations','is_org_owner',
 'create_organization','join_organization','review_participant','generate_fixture','set_match_result') loop
 execute format('revoke all on function %s from public,anon,authenticated',r.sig);
 execute format('grant execute on function %s to authenticated',r.sig);
 end loop;
end $$;

-- Only the organization-share branch changes; other social branches retain their source checks.
drop function if exists public.shared_content_card(text,uuid);
create or replace function public.shared_content_card(
  p_kind text, p_id uuid)
returns table (
  available bool,
  title     text,
  subtitle  text,
  image_ref text,
  route     text)
language sql
stable
security definer
set search_path = public
as $card$
  with hit as (
    select true as available, left(p.body, 120) as title,
           coalesce(pr.full_name, 'Bilinmeyen') as subtitle,
           p.image_path as image_ref, '/akis' as route
      from public.posts p
      left join public.profiles pr on pr.id = p.author_profile_id
     where p_kind = 'content_share'
       and p.id = p_id
       and public.can_view_post(p.id)
    union all
    select true, l.title,
           case when l.price is null then 'Fiyat belirtilmemiş'
                else trim(to_char(l.price, 'FM999G999G999')) || ' TL' end,
           null, '/urun'
      from public.listings l
     where p_kind = 'marketplace_share'
       and l.id = p_id
       and l.market_status = 'active'
       -- Engellenen kişinin ilanı görünmüyor (0052 kuralı).
       and not public.is_blocked_between(auth.uid(), l.owner_id)
    union all
    select true, e.title,
           to_char(e.starts_at at time zone 'Europe/Istanbul',
                   'DD.MM.YYYY HH24:MI'),
           null, '/calendar'
      from public.events e
     where p_kind = 'event_share'
       and e.id = p_id
       -- Etkinlik yalnızca kulüp üyesine görünüyor.
       and public.is_club_member(e.club_id)
    union all
    select true, o.name, coalesce(o.city_code, o.kind), null,
           '/organizasyonlar'
      from public.organizations o
     where p_kind = 'organization_share'
       and o.id = p_id
       and not o.official
  )
  select h.available, h.title, h.subtitle, h.image_ref, h.route
    from hit h
   where auth.uid() is not null
  union all
  -- Hiçbir satır yoksa: kaynak yok, silinmiş ya da erişim yok. Üç durumun
  -- AYRI mesajı yok — "silinmiş" ile "erişimin yok" arasındaki fark,
  -- olmayan bir içeriğin varlığını doğrulardı.
  select false, null::text, null::text, null::text, null::text
   where auth.uid() is null
      or not exists (select 1 from hit);
$card$;
revoke all on function public.shared_content_card(text,uuid) from public,anon,authenticated;
grant execute on function public.shared_content_card(text,uuid) to authenticated;
