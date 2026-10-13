set local lock_timeout = '15s';

-- Phase 1 only. Existing federation appointments, result writers, C1 and
-- health_restrictions remain authoritative; a role label does not bypass them.
create table if not exists public.federation_roles (
  id uuid primary key default gen_random_uuid(),
  federation_id uuid not null references public.federations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('president','board_member','general_secretary','provincial_rep','referee_committee','disciplinary_board')),
  city_code text references public.cities(code),
  starts_on date not null default current_date,
  ends_on date not null default (current_date + interval '1 year'),
  revoked_at timestamptz,
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  check (ends_on >= starts_on),
  check ((role = 'provincial_rep' and city_code is not null) or (role <> 'provincial_rep' and city_code is null))
);
create index if not exists idx_federation_roles_profile on public.federation_roles(profile_id,role) where revoked_at is null;
create table if not exists public.referee_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  license_number text not null unique check (length(trim(license_number)) between 1 and 80),
  badge_tier text not null check (badge_tier in ('candidate','provincial','national','international')),
  sport_code text not null references public.sports(code),
  city_code text not null references public.cities(code),
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);
create index if not exists idx_referee_profiles_sport_city on public.referee_profiles(sport_code,city_code) where is_active;
create table if not exists public.match_officials (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.org_matches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  duty text not null check (duty in ('head_referee','assistant_referee_1','assistant_referee_2','fourth_referee','table_official','observer')),
  status text not null default 'assigned' check (status in ('assigned','accepted','declined','replaced')),
  decline_reason text check (length(decline_reason) <= 500),
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default clock_timestamp(),
  responded_at timestamptz,
  unique (match_id,duty)
);
create index if not exists idx_match_officials_profile on public.match_officials(profile_id,status);
create index if not exists idx_match_officials_match on public.match_officials(match_id);
create table if not exists public.club_staff_roles (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('president','sporting_director','doctor','physiotherapist','kit_manager','media_officer')),
  assigned_at timestamptz not null default clock_timestamp(),
  unique (club_id,profile_id,role)
);
create index if not exists idx_club_staff_roles_club on public.club_staff_roles(club_id,role);
create table if not exists public.org_match_lineup_notes (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.org_matches(id) on delete cascade,
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  status text not null check (status in ('eligible','injured_admin','injured_medical','rested','suspended')),
  note text check (length(note) <= 500), -- Operational reason only, never a diagnosis/report.
  recorded_by uuid references public.profiles(id) on delete set null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique (match_id,athlete_id)
);
create index if not exists idx_match_lineup_notes_club on public.org_match_lineup_notes(club_id,match_id);

-- Durable UUID arrays deliberately have no athlete cascade FK, like the
-- existing official roster snapshots. No personal-name/health snapshot.
create table if not exists public.match_lineup_approvals (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.org_matches(id) on delete restrict,
  participant_id uuid not null references public.org_participants(id) on delete restrict,
  roster_revision_id uuid not null references public.org_roster_revisions(id) on delete restrict,
  starter_athlete_ids uuid[] not null,
  substitute_athlete_ids uuid[] not null default '{}',
  verified_by uuid references public.profiles(id) on delete set null,
  verified_at timestamptz not null default clock_timestamp(),
  is_locked boolean not null default true check (is_locked),
  notes text check (length(notes) <= 500),
  unique (match_id,participant_id),
  check (cardinality(starter_athlete_ids) between 1 and 200),
  check (cardinality(starter_athlete_ids) + cardinality(substitute_athlete_ids) <= 200),
  check (array_position(starter_athlete_ids,null) is null and array_position(substitute_athlete_ids,null) is null)
);
create index if not exists idx_match_lineup_approvals_participant on public.match_lineup_approvals(participant_id,match_id);

-- Remove dependents first so replay does not require destructive CASCADE.
drop policy if exists federation_roles_read on public.federation_roles;
drop policy if exists referee_profiles_read on public.referee_profiles;
drop policy if exists match_officials_read on public.match_officials;
drop policy if exists club_staff_roles_read on public.club_staff_roles;
drop policy if exists org_match_lineup_notes_read on public.org_match_lineup_notes;
drop policy if exists match_lineup_approvals_read on public.match_lineup_approvals;
drop trigger if exists match_lineup_immutable on public.match_lineup_approvals;
drop trigger if exists match_lineup_fixture_guard on public.org_matches;
drop trigger if exists referee_profile_timestamp on public.referee_profiles;
drop function if exists public.referee_verify_lineup(uuid,uuid[],uuid[],text);
drop function if exists public.referee_verify_lineup(uuid,uuid[],uuid[],text,uuid[],uuid[]);
drop function if exists public.respond_match_assignment(uuid,boolean,text);
drop function if exists public.my_referee_matches(text);
drop function if exists public.accepted_match_officials(uuid);
drop function if exists public.referee_lineup_card(uuid);
drop function if exists public.set_match_lineup_note(uuid,uuid,text,text);
drop function if exists public._sports_lineup_guard();
drop function if exists public._sports_role_read(uuid);
drop function if exists public._sports_assignment_read(uuid);
drop function if exists public._sports_approval_read(uuid,uuid);
drop function if exists public._sports_roster_validate(uuid,uuid[],uuid[]);
drop function if exists public._sports_match_read(uuid,uuid);
drop function if exists public._sports_club_read(uuid);
drop function if exists public._sports_federation_scope(text,text,text[]);
drop function if exists public.is_match_official(uuid);
drop function if exists public.is_provincial_rep(text,text);
drop function if exists public.is_federation_president(text);

create function public.is_federation_president(p_sport_code text default null)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.federation_roles r join public.federations f on f.id=r.federation_id
    where r.profile_id=auth.uid() and r.role='president' and r.revoked_at is null
      and (now() at time zone 'Europe/Istanbul')::date between r.starts_on and r.ends_on
      and (p_sport_code is null or f.sport_code=p_sport_code)
  )
$$;
create function public.is_provincial_rep(p_city_code text,p_sport_code text default null)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select public.is_federation_president(p_sport_code) or exists (
    select 1 from public.federation_roles r join public.federations f on f.id=r.federation_id
    where r.profile_id=auth.uid() and r.role='provincial_rep' and r.city_code=p_city_code and r.revoked_at is null
      and (now() at time zone 'Europe/Istanbul')::date between r.starts_on and r.ends_on
      and (p_sport_code is null or f.sport_code=p_sport_code)
  )
$$;
create function public._sports_federation_scope(p_sport text,p_city text,p_roles text[])
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.federation_roles r join public.federations f on f.id=r.federation_id
    where r.profile_id=auth.uid() and f.sport_code=p_sport and r.revoked_at is null
      and (now() at time zone 'Europe/Istanbul')::date between r.starts_on and r.ends_on
      and (r.role='president' or (r.role='provincial_rep' and r.city_code=p_city) or r.role=any(p_roles))
  )
$$;
create function public.is_match_official(p_match_id uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.match_officials mo
    join public.org_matches m on m.id=mo.match_id join public.organizations o on o.id=m.org_id
    join public.referee_profiles rp on rp.profile_id=mo.profile_id and rp.sport_code=o.sport_code and rp.is_active
    where mo.match_id=p_match_id and mo.profile_id=auth.uid() and mo.status in ('assigned','accepted') and o.official
  )
$$;
create function public._sports_club_read(p_club uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select public.is_club_staff(p_club) or public.is_authorized_health_officer(p_club)
$$;
create function public._sports_match_read(p_match uuid,p_club uuid default null)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.org_matches m join public.organizations o on o.id=m.org_id
    where m.id=p_match and o.official and (
      public.is_match_official(m.id)
      or public._sports_federation_scope(o.sport_code,o.city_code,array['referee_committee','disciplinary_board'])
      or exists (select 1 from public.org_participants p where p.id in(m.home_id,m.away_id)
        and (p_club is null or p.club_id=p_club) and public._sports_club_read(p.club_id))
    )
  )
$$;

-- Legacy official tables intentionally deny raw SELECT. Resolve policy scope
-- inside definer predicates, not caller-side subqueries of those tables.
create function public._sports_role_read(p_federation uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.federations f where f.id=p_federation and public.is_federation_president(f.sport_code))
$$;
create function public._sports_assignment_read(p_match uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.org_matches m join public.organizations o on o.id=m.org_id
    where m.id=p_match and o.official and public._sports_federation_scope(o.sport_code,o.city_code,array['referee_committee']))
$$;
create function public._sports_approval_read(p_match uuid,p_participant uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.org_participants p where p.id=p_participant
    and ((p.club_id is not null and public._sports_match_read(p_match,p.club_id))
      or public.is_match_official(p_match) or public._sports_assignment_read(p_match)))
$$;

create function public.my_referee_matches(p_status text default null)
returns table (official_id uuid,match_id uuid,duty text,status text,assigned_at timestamptz,
  starts_at timestamptz,location text,sport_code text,home_club_name text,away_club_name text,decline_reason text)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
  if p_status is not null and p_status not in ('assigned','accepted','declined','replaced') then
    raise exception 'Atama filtresi geçersiz' using errcode='22023'; end if;
  return query
  select mo.id,m.id,mo.duty,mo.status,mo.assigned_at,m.starts_at,m.location,o.sport_code,
    coalesce(ch.legal_name,ch.name),coalesce(ca.legal_name,ca.name),mo.decline_reason
  from public.match_officials mo join public.org_matches m on m.id=mo.match_id
  join public.organizations o on o.id=m.org_id and o.official
  left join public.org_participants ph on ph.id=m.home_id left join public.clubs ch on ch.id=ph.club_id
  left join public.org_participants pa on pa.id=m.away_id left join public.clubs ca on ca.id=pa.club_id
  where mo.profile_id=auth.uid() and (p_status is null or mo.status=p_status)
  order by m.starts_at nulls last,m.id,mo.duty;
end $$;

-- The sole public projection: no assignment IDs, profile IDs, licenses,
-- declined/replaced rows, reasons or timestamps. Unpublished programs stay private.
create function public.accepted_match_officials(p_match_id uuid)
returns table (name text,duty text)
language sql stable security definer set search_path = public, pg_temp as $$
  select p.full_name,mo.duty from public.match_officials mo
  join public.profiles p on p.id=mo.profile_id join public.org_matches m on m.id=mo.match_id
  join public.organizations o on o.id=m.org_id
  where m.id=p_match_id and o.official and mo.status='accepted'
    and (o.is_public or public._sports_match_read(m.id))
  order by mo.duty
$$;

create function public.respond_match_assignment(p_official_id uuid,p_accept boolean,p_reason text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare mo public.match_officials; v_match uuid;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
  if p_accept is null or length(coalesce(p_reason,''))>500 then raise exception 'Yanıt geçersiz' using errcode='22023'; end if;
  perform 1 from public.profiles where id=auth.uid() for key share;
  if not found then raise exception 'Hesap erişilemez' using errcode='42501'; end if;
  select match_id into v_match from public.match_officials where id=p_official_id and profile_id=auth.uid();
  if not found then raise exception 'Atama erişilemez' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(110,hashtext(v_match::text));
  select * into mo from public.match_officials where id=p_official_id and profile_id=auth.uid() for update;
  if mo.status in ('declined','replaced') then raise exception 'Atama kapanmış' using errcode='55000'; end if;
  if exists(select 1 from public.match_lineup_approvals where match_id=v_match)
    or exists(select 1 from public.org_matches where id=v_match and (status<>'scheduled' or result_version>0)) then
    raise exception 'Maç/esame kilitli' using errcode='55000'; end if;
  if p_accept and not exists(select 1 from public.referee_profiles rp
    join public.org_matches m on m.id=v_match join public.organizations o on o.id=m.org_id
    where rp.profile_id=auth.uid() and rp.is_active and rp.sport_code=o.sport_code and o.official) then
    raise exception 'Aktif aynı branş hakem kaydı gerekli' using errcode='42501'; end if;
  if mo.status='accepted' and p_accept then return; end if;
  update public.match_officials set status=case when p_accept then 'accepted' else 'declined' end,
    decline_reason=case when p_accept then null else nullif(trim(p_reason),'') end,
    responded_at=clock_timestamp() where id=mo.id;
  insert into public.federation_audit(actor_id,action,entity_id,detail)
    values(auth.uid(),'match_assignment_response',mo.id,jsonb_build_object('previous',mo.status,'status',case when p_accept then 'accepted' else 'declined' end));
end $$;

-- Shared validation locks the participant, preventing simultaneous roster
-- publication; rechecks club/team/sport/license/C1/health and match-local notes.
create function public._sports_roster_validate(p_participant uuid,p_starters uuid[],p_subs uuid[])
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare p public.org_participants; o public.organizations; rr public.org_roster_revisions; ids uuid[]; a uuid;
begin
  select * into p from public.org_participants where id=p_participant for share;
  select * into o from public.organizations where id=p.org_id and official;
  ids:=p_starters||p_subs;
  if o.id is null or p.status<>'accepted' or p.club_id is null or p_starters is null or p_subs is null
    or cardinality(p_starters) not between 1 and 200 or cardinality(ids)>200
    or array_position(ids,null) is not null
    or cardinality(ids)<>(select count(distinct x) from unnest(ids) x) then
    raise exception 'Esame dizileri geçersiz' using errcode='22023'; end if;
  select * into rr from public.org_roster_revisions where participant_id=p.id order by version desc limit 1 for share;
  if rr.id is null or not ids <@ rr.athlete_ids then raise exception 'Esame yayımlanmış kadrodan seçilmeli' using errcode='22023'; end if;
  foreach a in array ids loop
    if not exists(select 1 from public.athletes at join public.athlete_sport_registrations r on r.athlete_id=at.id
      where at.id=a and at.club_id=p.club_id and r.club_id=p.club_id and r.sport_code=o.sport_code
        and r.expires_on>=o.ends_on and r.expires_on>=(clock_timestamp() at time zone 'Europe/Istanbul')::date
        and (p.team_id is null or exists(select 1 from public.team_memberships tm where tm.team_id=p.team_id and tm.athlete_id=at.id)))
      or exists(select 1 from public.eligibility_gate(a) g where g.blocked and g.reason_code<>'license_expired') then
      raise exception 'Sporcu kulüp/takım/lisans/sağlık şartını karşılamıyor' using errcode='22023'; end if;
    perform public._c1_require_athlete(a,p.club_id,o.sport_code);
  end loop;
  return rr.id;
end $$;

-- One signature, four original arguments still work via trailing defaults.
create function public.referee_verify_lineup(p_match_id uuid,p_home_roster uuid[],p_away_roster uuid[],
  p_notes text default null,p_home_substitutes uuid[] default '{}',p_away_substitutes uuid[] default '{}')
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare m public.org_matches; o public.organizations; hr uuid; ar uuid; mo uuid; rp uuid; ids uuid[];
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
  if length(coalesce(p_notes,''))>500 then raise exception 'Not çok uzun' using errcode='22023'; end if;
  perform 1 from public.profiles where id=auth.uid() for key share;
  if not found then raise exception 'Hesap erişilemez' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(110,hashtext(p_match_id::text));
  select * into m from public.org_matches where id=p_match_id for update;
  select * into o from public.organizations where id=m.org_id and official;
  if o.id is null or m.status<>'scheduled' or m.result_version<>0 then raise exception 'Açık resmi maç gerekli' using errcode='55000'; end if;
  select x.id,r.id into mo,rp from public.match_officials x join public.referee_profiles r on r.profile_id=x.profile_id
    where x.match_id=m.id and x.profile_id=auth.uid() and x.status='accepted'
      and x.duty in ('head_referee','table_official') and r.is_active and r.sport_code=o.sport_code
    order by x.id limit 1 for share of x,r;
  if mo is null then raise exception 'Kabul edilmiş başhakem/masa hakemi görevi gerekli' using errcode='42501'; end if;
  if exists(select 1 from public.match_lineup_approvals where match_id=m.id) then raise exception 'Esame kilitli' using errcode='55000'; end if;
  if m.home_id is null then raise exception 'Ev sahibi katılımcı gerekli' using errcode='22023'; end if;
  hr:=public._sports_roster_validate(m.home_id,p_home_roster,p_home_substitutes);
  if m.away_id is not null then
    ar:=public._sports_roster_validate(m.away_id,p_away_roster,p_away_substitutes);
  elsif cardinality(coalesce(p_away_roster,'{}'))>0 or cardinality(coalesce(p_away_substitutes,'{}'))>0 then
    raise exception 'Deplasman katılımcısı yok' using errcode='22023'; end if;
  ids:=p_home_roster||p_home_substitutes||coalesce(p_away_roster,'{}')||coalesce(p_away_substitutes,'{}');
  if cardinality(ids)<>(select count(distinct x) from unnest(ids) x)
    or exists(select 1 from public.org_match_lineup_notes n where n.match_id=m.id and n.athlete_id=any(ids) and n.status<>'eligible') then
    raise exception 'Esame çakışması/idari veya tıbbi kısıt' using errcode='22023'; end if;
  insert into public.match_lineup_approvals(match_id,participant_id,roster_revision_id,starter_athlete_ids,substitute_athlete_ids,verified_by,notes)
    values(m.id,m.home_id,hr,p_home_roster,p_home_substitutes,auth.uid(),p_notes);
  if m.away_id is not null then
    insert into public.match_lineup_approvals(match_id,participant_id,roster_revision_id,starter_athlete_ids,substitute_athlete_ids,verified_by,notes)
      values(m.id,m.away_id,ar,p_away_roster,p_away_substitutes,auth.uid(),p_notes);
  end if;
  insert into public.federation_audit(actor_id,action,entity_id,detail)
    values(auth.uid(),'match_lineup_verified',m.id,jsonb_build_object('home_roster_revision',hr,'away_roster_revision',ar));
end $$;

create function public.set_match_lineup_note(p_match_id uuid,p_athlete_id uuid,p_status text,p_note text default null)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare c uuid; o public.organizations; previous text; has_medical boolean;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
  if p_status is null or p_status not in ('eligible','injured_admin','injured_medical','rested','suspended')
    or length(coalesce(p_note,''))>500 then raise exception 'Durum/not geçersiz' using errcode='22023'; end if;
  perform 1 from public.profiles where id=auth.uid() for key share;
  if not found then raise exception 'Hesap erişilemez' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(110,hashtext(p_match_id::text));
  perform 1 from public.org_matches where id=p_match_id and status='scheduled' and result_version=0 for update;
  if not found or exists(select 1 from public.match_lineup_approvals where match_id=p_match_id) then
    raise exception 'Maç/esame kilitli' using errcode='55000'; end if;
  select a.club_id into c from public.athletes a where a.id=p_athlete_id;
  select org.* into o from public.org_matches m join public.organizations org on org.id=m.org_id and org.official
    where m.id=p_match_id and exists(select 1 from public.org_participants p where p.id in(m.home_id,m.away_id) and p.club_id=c);
  if o.id is null then raise exception 'Maç/sporcu kulübü uyuşmuyor' using errcode='22023'; end if;
  select n.status into previous from public.org_match_lineup_notes n where n.match_id=p_match_id and n.athlete_id=p_athlete_id for update;
  if p_status='injured_medical' or previous='injured_medical' then
    if not public.is_authorized_health_officer(c) then raise exception 'Tıbbi kilit yalnız sağlık görevlisince değişir' using errcode='42501'; end if;
    perform 1 from public.club_staff_permissions sp join public.club_memberships cm
      on cm.club_id=sp.club_id and cm.profile_id=sp.profile_id
      where sp.club_id=c and sp.profile_id=auth.uid() and sp.revoked_at is null and sp.can_verify_medical
        and cm.status='active' for share of sp,cm;
    if not found then raise exception 'Sağlık yetkisi değişmiş' using errcode='42501'; end if;
  end if;
  -- Independent checks: changing a medical lock into a disciplinary state
  -- (or vice versa) must not bypass either authority.
  if p_status='suspended' or previous='suspended' then
    if not public._sports_federation_scope(o.sport_code,o.city_code,array['disciplinary_board']) then
      raise exception 'Disiplin yetkisi gerekli' using errcode='42501'; end if;
  end if;
  if p_status not in ('injured_medical','suspended')
    and coalesce(previous,'eligible') not in ('injured_medical','suspended') then
    perform 1 from public.club_memberships cm where cm.club_id=c and cm.profile_id=auth.uid()
      and cm.status='active' and (cm.role in ('club_admin','coach') or public.is_authorized_health_officer(c)) for share;
    if not found then raise exception 'Kulüp sportif/sağlık yetkisi gerekli' using errcode='42501'; end if;
  end if;
  select exists(select 1 from public.club_staff_permissions sp join public.club_memberships cm
    on cm.club_id=sp.club_id and cm.profile_id=sp.profile_id and cm.status='active'
    where sp.club_id=c and sp.revoked_at is null and sp.can_verify_medical) into has_medical;
  if p_status='injured_admin' and has_medical then raise exception 'Sakatlık sağlık görevlisine iletilmeli; idari dinlenme için rested kullanın' using errcode='22023'; end if;
  if p_status='eligible' and exists(select 1 from public.health_restrictions h where h.athlete_id=p_athlete_id and h.status='restricted') then
    raise exception 'Mevcut sağlık kısıtı önce yetkili sağlık akışında kaldırılmalı' using errcode='55000'; end if;
  insert into public.org_match_lineup_notes(match_id,athlete_id,club_id,status,note,recorded_by)
    values(p_match_id,p_athlete_id,c,p_status,p_note,auth.uid())
    on conflict(match_id,athlete_id) do update set status=excluded.status,note=excluded.note,
      recorded_by=auth.uid(),recorded_at=clock_timestamp();
  insert into public.federation_audit(actor_id,action,entity_id,detail)
    values(auth.uid(),'match_lineup_note',p_match_id,jsonb_build_object('athlete_id',p_athlete_id,'previous',previous,'status',p_status));
end $$;

create function public._sports_lineup_guard()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if tg_table_name='match_lineup_approvals' then
    -- Account deletion may null only the author; the sporting snapshot survives.
    if tg_op='UPDATE' and pg_trigger_depth()>1 and new.verified_by is null and old.verified_by is not null
      and (to_jsonb(new)-'verified_by')=(to_jsonb(old)-'verified_by') then return new; end if;
    raise exception 'Onaylanmış maç esamesi değiştirilemez/silinemez' using errcode='55000';
  end if;
  if exists(select 1 from public.match_lineup_approvals where match_id=old.id)
    and (new.org_id,new.home_id,new.away_id) is distinct from (old.org_id,old.home_id,old.away_id) then
    raise exception 'Esamesi kilitlenmiş maçın tarafları değiştirilemez' using errcode='55000'; end if;
  return new;
end $$;
create trigger match_lineup_immutable before update or delete on public.match_lineup_approvals
  for each row execute function public._sports_lineup_guard();
create trigger match_lineup_fixture_guard before update on public.org_matches
  for each row execute function public._sports_lineup_guard();
create trigger referee_profile_timestamp before update on public.referee_profiles
  for each row execute function public.set_updated_at();

-- A private, allowlisted card. No TC/guardian phone, medical notes, DOB,
-- athlete/profile UUID or generic profiles/athletes SELECT grant is introduced.
create function public.referee_lineup_card(p_match_id uuid)
returns table (side text,name text,jersey_number int,license_number text,license_expires_on date)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not exists(select 1 from public.match_officials mo where mo.match_id=p_match_id and mo.profile_id=auth.uid()
    and mo.status='accepted') or not public.is_match_official(p_match_id) then
    raise exception 'Kabul edilmiş maç görevi gerekli' using errcode='42501'; end if;
  return query
  select case when p.id=m.home_id then 'home' else 'away' end,
    case when (a.birth_date is null or a.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date)
      and (not exists(select 1 from public.athlete_publicity ap join public.guardians g on g.id=ap.guardian_id
        where ap.athlete_id=a.id and ap.allowed and g.profile_id is not null)
        or exists(select 1 from public.athlete_publicity ap join public.guardians g on g.id=ap.guardian_id
        where ap.athlete_id=a.id and not ap.allowed and g.profile_id is not null))
      then null else trim(a.first_name||' '||a.last_name) end,
    a.jersey_number,r.license_number,r.expires_on
  from public.org_matches m join public.organizations o on o.id=m.org_id
  join public.org_participants p on p.id in(m.home_id,m.away_id)
  left join public.match_lineup_approvals la on la.match_id=m.id and la.participant_id=p.id
  join lateral (select rr.athlete_ids from public.org_roster_revisions rr where rr.participant_id=p.id
    and (la.id is null or rr.id=la.roster_revision_id) order by rr.version desc limit 1) rr on true
  join public.athletes a on a.id=any(case when la.id is null then rr.athlete_ids else la.starter_athlete_ids||la.substitute_athlete_ids end)
  join public.athlete_sport_registrations r on r.athlete_id=a.id and r.sport_code=o.sport_code
  where m.id=p_match_id;
end $$;

-- All source tables are authenticated/scoped reads, no client direct writes.
do $$ declare t text; begin
  foreach t in array array['federation_roles','referee_profiles','match_officials','club_staff_roles','org_match_lineup_notes','match_lineup_approvals'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public,anon,authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
  end loop;
end $$;
create policy federation_roles_read on public.federation_roles for select to authenticated using (
  profile_id=auth.uid() or public._sports_role_read(federation_id)
);
create policy referee_profiles_read on public.referee_profiles for select to authenticated using (
  profile_id=auth.uid() or public._sports_federation_scope(sport_code,city_code,array['referee_committee'])
);
create policy match_officials_read on public.match_officials for select to authenticated using (
  profile_id=auth.uid() or public._sports_assignment_read(match_id)
);
create policy club_staff_roles_read on public.club_staff_roles for select to authenticated using (
  profile_id=auth.uid() or public._sports_club_read(club_id)
);
create policy org_match_lineup_notes_read on public.org_match_lineup_notes for select to authenticated using (
  public._sports_match_read(match_id,club_id)
);
create policy match_lineup_approvals_read on public.match_lineup_approvals for select to authenticated using (
  public._sports_approval_read(match_id,participant_id)
);

-- Boolean policy predicates need EXECUTE for RLS. They reveal authorization
-- only; row validators and mutation triggers are never executable by clients.
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in ('is_federation_president','is_provincial_rep','is_match_official',
      '_sports_federation_scope','_sports_club_read','_sports_match_read','_sports_roster_validate','_sports_lineup_guard',
      '_sports_role_read','_sports_assignment_read','_sports_approval_read',
      'my_referee_matches','respond_match_assignment','referee_verify_lineup','set_match_lineup_note','referee_lineup_card','accepted_match_officials') loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
    if f.signature::text !~ '_sports_roster_validate|_sports_lineup_guard' then
      execute format('grant execute on function %s to authenticated',f.signature);
    end if;
  end loop;
end $$;
grant execute on function public.accepted_match_officials(uuid) to anon;

comment on table public.club_staff_roles is 'İhtisas etiketi; can_verify_medical/aktif üyelik izninin yerine geçmez.';
comment on table public.match_lineup_approvals is 'Maç bazlı değişmez esame; org_roster_revisions ve resmi sonuç yazıcıları değiştirilmez.';
