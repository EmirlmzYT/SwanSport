set local lock_timeout = '15s';

create or replace function public._club_active_staff(p_club uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from club_memberships where club_id=p_club and profile_id=auth.uid() and status='active' and role in ('club_admin','coach','official'))
$$;

create or replace function public._club_specialist(p_club uuid,p_roles text[])
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and exists(select 1 from club_staff_roles r join club_memberships m
  on m.club_id=r.club_id and m.profile_id=r.profile_id where r.club_id=p_club and r.profile_id=auth.uid()
   and r.role=any(p_roles) and m.status='active')
$$;
create or replace function public._inventory_read(p_club uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select public._club_active_staff(p_club) or public._club_specialist(p_club,array['kit_manager','sporting_director','president'])
$$;
create or replace function public._inventory_write(p_club uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from club_memberships m where m.club_id=p_club and m.profile_id=auth.uid() and m.role='club_admin' and m.status='active')
  or public._club_specialist(p_club,array['kit_manager'])
$$;
create or replace function public._club_health_read(p_club uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select public._club_active_staff(p_club) or public.is_authorized_health_officer(p_club) or public._club_specialist(p_club,array['president'])
$$;

create table if not exists public.club_inventory_items (
 id uuid primary key default gen_random_uuid(),club_id uuid not null references public.clubs(id) on delete cascade,
 name text not null check(length(trim(name)) between 1 and 120),category text not null check(length(category) between 1 and 80),
 quantity int not null check(quantity between 1 and 1000000),sport_code text references public.sports(code),
 status text not null default 'active' check(status in ('active','retired')),
 damaged_quantity int not null default 0,missing_quantity int not null default 0,
 created_by uuid references public.profiles(id) on delete set null,
 check(damaged_quantity>=0 and missing_quantity>=0 and damaged_quantity+missing_quantity<=quantity));
create table if not exists public.club_inventory_assignments (
 id uuid primary key default gen_random_uuid(),item_id uuid not null references public.club_inventory_items(id) on delete cascade,
 assigned_to_profile_id uuid references public.profiles(id) on delete set null,
 assigned_to_team_id uuid references public.teams(id) on delete set null,
 quantity int not null check(quantity between 1 and 1000000),assigned_at timestamptz not null default clock_timestamp(),
 returned_at timestamptz,notes text check(length(notes)<=500),
 outcome text not null default 'pending' check(outcome in ('pending','returned','damaged','missing')),
 created_by uuid references public.profiles(id) on delete set null,
 check((returned_at is null and outcome='pending') or (returned_at is not null and outcome<>'pending')));
create index if not exists inventory_assignments_item on public.club_inventory_assignments(item_id) where returned_at is null;
create table if not exists public.club_inventory_audit (
 id bigint generated always as identity primary key,club_id uuid not null,
 actor_id uuid references public.profiles(id) on delete set null,action text not null,entity_id uuid not null,
 recorded_at timestamptz not null default clock_timestamp(),detail jsonb not null default '{}');
alter table public.club_inventory_items enable row level security;
alter table public.club_inventory_assignments enable row level security;
alter table public.club_inventory_audit enable row level security;
revoke all on public.club_inventory_items,public.club_inventory_assignments,public.club_inventory_audit from public,anon,authenticated;
grant select on public.club_inventory_items,public.club_inventory_assignments to authenticated;
drop policy if exists inventory_items_read on public.club_inventory_items;
create policy inventory_items_read on public.club_inventory_items for select to authenticated using(public._inventory_read(club_id));
drop policy if exists inventory_assignments_read on public.club_inventory_assignments;
create policy inventory_assignments_read on public.club_inventory_assignments for select to authenticated using(
 exists(select 1 from public.club_inventory_items i where i.id=item_id and public._inventory_read(i.club_id)));

create or replace function public._inventory_require(p_club uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$ begin
 if auth.uid() is null then raise exception 'Oturum gerekli' using errcode='42501'; end if;
 perform 1 from profiles where id=auth.uid() for key share;
 perform 1 from clubs where id=p_club for key share;
 perform 1 from club_memberships where club_id=p_club and profile_id=auth.uid() and status='active' for share;
 perform 1 from club_staff_roles where club_id=p_club and profile_id=auth.uid() for share;
 if not public._inventory_write(p_club) then raise exception 'Aktif kulüp yöneticisi/malzeme sorumlusu gerekli' using errcode='42501'; end if;
end $$;

create or replace function public.inventory_add_item(p_id uuid,p_club uuid,p_name text,p_category text,p_quantity int,p_sport text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i club_inventory_items;begin
 perform public._inventory_require(p_club);
 insert into club_inventory_items(id,club_id,name,category,quantity,sport_code,created_by)
 values(p_id,p_club,trim(p_name),trim(p_category),p_quantity,p_sport,auth.uid()) on conflict(id) do nothing returning * into i;
 if i.id is null then
  select * into i from club_inventory_items where id=p_id;
  if (i.club_id,i.name,i.category,i.quantity,i.sport_code,i.created_by) is distinct from (p_club,trim(p_name),trim(p_category),p_quantity,p_sport,auth.uid()) then
   raise exception 'İşlem kimliği farklı malzemeye ait' using errcode='22023'; end if;return i.id;
 end if;
 insert into club_inventory_audit(club_id,actor_id,action,entity_id) values(p_club,auth.uid(),'item_created',i.id);return i.id;
end $$;
create or replace function public.inventory_assign(p_id uuid,p_item uuid,p_quantity int,p_profile uuid default null,p_team uuid default null,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare i club_inventory_items;a club_inventory_assignments;used int;begin
 select club_id into i.club_id from club_inventory_items where id=p_item;
 if not public._inventory_write(i.club_id) then raise exception 'Aktif kulüp yöneticisi/malzeme sorumlusu gerekli' using errcode='42501';end if;
 -- Parent FK locks precede the item/assignment row locks (account deletion).
 perform 1 from profiles where id in(auth.uid(),p_profile,(select created_by from club_inventory_items where id=p_item)) order by id for key share;
 if p_team is not null then perform 1 from teams where id=p_team for key share;end if;
 perform public._inventory_require(i.club_id);
 select * into i from club_inventory_items where id=p_item for update;
 if i.id is null then raise exception 'Malzeme erişilemez' using errcode='42501'; end if;
 select * into a from club_inventory_assignments where id=p_id;
 if found then
  if (a.item_id,a.quantity,a.assigned_to_profile_id,a.assigned_to_team_id,a.notes,a.created_by) is distinct from
   (p_item,p_quantity,p_profile,p_team,p_notes,auth.uid()) then raise exception 'İşlem kimliği farklı zimmete ait' using errcode='22023'; end if;return a.id;
 end if;
 if p_quantity is null or p_quantity<=0 or (p_profile is null)=(p_team is null) or i.status<>'active' then raise exception 'Tek hedef ve pozitif miktar gerekli' using errcode='22023'; end if;
 if p_profile is not null then
  perform 1 from club_memberships where club_id=i.club_id and profile_id=p_profile and status='active' for share;
  if not found then raise exception 'Hedef aktif kulüp üyesi olmalı' using errcode='22023'; end if;
 else
  perform 1 from teams where id=p_team and club_id=i.club_id for share;
  if not found then raise exception 'Hedef takım aynı kulüpte olmalı' using errcode='22023'; end if;
 end if;
 select coalesce(sum(quantity),0) into used from club_inventory_assignments where item_id=i.id and returned_at is null;
 if p_quantity>i.quantity-i.damaged_quantity-i.missing_quantity-used then raise exception 'Kullanılabilir stok yetersiz' using errcode='22023'; end if;
 insert into club_inventory_assignments(id,item_id,assigned_to_profile_id,assigned_to_team_id,quantity,notes,created_by)
 values(p_id,i.id,p_profile,p_team,p_quantity,p_notes,auth.uid());
 insert into club_inventory_audit(club_id,actor_id,action,entity_id,detail) values(i.club_id,auth.uid(),'assigned',p_id,jsonb_build_object('quantity',p_quantity));return p_id;
end $$;
create or replace function public.inventory_return(p_assignment uuid,p_outcome text default 'returned')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare i club_inventory_items;a club_inventory_assignments;begin
 select x.* into i from club_inventory_items x join club_inventory_assignments issued on issued.item_id=x.id where issued.id=p_assignment;
 if not public._inventory_write(i.club_id) then raise exception 'Aktif kulüp yöneticisi/malzeme sorumlusu gerekli' using errcode='42501';end if;
 select * into a from club_inventory_assignments where id=p_assignment;
 perform 1 from profiles where id in(auth.uid(),i.created_by,a.created_by,a.assigned_to_profile_id) order by id for key share;
 if a.assigned_to_team_id is not null then perform 1 from teams where id=a.assigned_to_team_id for key share;end if;
 perform public._inventory_require(i.club_id);
 perform 1 from club_inventory_items where id=i.id for update;
 select * into a from club_inventory_assignments where id=p_assignment for update;
 if a.returned_at is not null then
  if a.outcome is distinct from p_outcome then raise exception 'Zimmet farklı sonuçla kapanmış' using errcode='55000'; end if;return;
 end if;
 if p_outcome is null or p_outcome not in ('returned','damaged','missing') then raise exception 'İade sonucu geçersiz' using errcode='22023'; end if;
 update club_inventory_assignments set returned_at=clock_timestamp(),outcome=p_outcome where id=a.id;
 update club_inventory_items set damaged_quantity=damaged_quantity+case when p_outcome='damaged' then a.quantity else 0 end,
 missing_quantity=missing_quantity+case when p_outcome='missing' then a.quantity else 0 end where id=i.id;
 insert into club_inventory_audit(club_id,actor_id,action,entity_id,detail) values(i.club_id,auth.uid(),'returned',a.id,jsonb_build_object('outcome',p_outcome,'quantity',a.quantity));
end $$;
create or replace function public.club_inventory_board(p_club uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$ begin
 if not public._inventory_read(p_club) then raise exception 'Kulüp envanter yetkisi gerekli' using errcode='42501'; end if;
 return jsonb_build_object('items',coalesce((select jsonb_agg(to_jsonb(q)) from (
  select i.*,i.quantity-i.damaged_quantity-i.missing_quantity-coalesce((select sum(a.quantity) from club_inventory_assignments a where a.item_id=i.id and a.returned_at is null),0) available
  from club_inventory_items i where club_id=p_club order by name,id) q),'[]'::jsonb),
 'assignments',coalesce((select jsonb_agg(to_jsonb(q)) from (select a.*,coalesce(t.name,public.athlete_ref(a.assigned_to_profile_id),'Silinmiş hedef') target_reference,
  i.name item_name from club_inventory_assignments a join club_inventory_items i on i.id=a.item_id left join teams t on t.id=a.assigned_to_team_id
  where i.club_id=p_club order by a.assigned_at desc,a.id) q),'[]'::jsonb),
 'targets',coalesce((select jsonb_agg(to_jsonb(q)) from (
  select distinct m.profile_id id,'profile'::text kind,public.athlete_ref(m.profile_id) label from club_memberships m where m.club_id=p_club and m.status='active'
  union all select t.id,'team',t.name from teams t where t.club_id=p_club) q),'[]'::jsonb));
end $$;

create table if not exists public.club_athlete_rest (
 athlete_id uuid primary key references public.athletes(id) on delete cascade,
 club_id uuid not null references public.clubs(id) on delete cascade,
 status text not null check(status in ('rested','injured_admin')),ends_at timestamptz,
 recorded_by uuid references public.profiles(id) on delete set null,recorded_at timestamptz not null default clock_timestamp());
alter table public.club_athlete_rest enable row level security;
revoke all on public.club_athlete_rest from public,anon,authenticated;
create or replace function public._club_rest_active(p_athlete uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from club_athlete_rest r join athletes a on a.id=r.athlete_id and a.club_id=r.club_id
 where r.athlete_id=p_athlete and (r.ends_at is null or r.ends_at>clock_timestamp()))
$$;
create or replace function public.set_club_athlete_rest(p_athlete uuid,p_status text,p_ends_at timestamptz default null)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare c uuid;current_club uuid;begin
 if auth.uid() is null then raise exception 'Oturum gerekli' using errcode='42501'; end if;
 select club_id into c from athletes where id=p_athlete;
 perform 1 from profiles where id=auth.uid() for key share;
 perform pg_advisory_xact_lock(113,0);
 perform 1 from clubs where id=c for key share;
 select club_id into current_club from athletes where id=p_athlete for share;
 if c is distinct from current_club then raise exception 'Sporcu kulübü değişti' using errcode='40001';end if;
 perform 1 from club_memberships where club_id=c and profile_id=auth.uid() and status='active' and role in ('coach','club_admin') for share;
 if not found then
  perform 1 from club_memberships where club_id=c and profile_id=auth.uid() and status='active' for share;
  perform 1 from club_staff_roles where club_id=c and profile_id=auth.uid() and role='president' for share;
  if not public._club_specialist(c,array['president']) then raise exception 'Aktif antrenör/yönetici gerekli' using errcode='42501';end if;
 end if;
 if p_status is null or p_status not in ('eligible','rested','injured_admin') or (p_ends_at is not null and p_ends_at<=clock_timestamp()) then raise exception 'İdari durum/süre geçersiz' using errcode='22023'; end if;
 if p_status='injured_admin' and exists(select 1 from club_staff_permissions sp join club_memberships m
  on m.club_id=sp.club_id and m.profile_id=sp.profile_id where sp.club_id=c and sp.can_verify_medical and sp.revoked_at is null and m.status='active') then
  raise exception 'Yetkili sağlık görevlisi var; tıbbi kısıt için hekim gerekli' using errcode='42501'; end if;
 if p_status='eligible' then delete from club_athlete_rest where athlete_id=p_athlete;
 else insert into club_athlete_rest(athlete_id,club_id,status,ends_at,recorded_by) values(p_athlete,c,p_status,p_ends_at,auth.uid())
 on conflict(athlete_id) do update set club_id=excluded.club_id,status=excluded.status,ends_at=excluded.ends_at,recorded_by=auth.uid(),recorded_at=clock_timestamp();end if;
 -- Only operational state. No diagnosis, narrative or medical override.
 insert into club_inventory_audit(club_id,actor_id,action,entity_id,detail) values(c,auth.uid(),'administrative_rest',p_athlete,jsonb_build_object('status',p_status));
end $$;

create or replace function public._club_operation_actor_lock(p_club uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$ begin
 if auth.uid() is null then raise exception 'Oturum gerekli' using errcode='42501'; end if;
 perform 1 from profiles where id=auth.uid() for key share;
 perform pg_advisory_xact_lock(113,0);
 perform 1 from clubs where id=p_club for key share;
 perform 1 from club_memberships where club_id=p_club and profile_id=auth.uid() and status='active' for share;
 perform 1 from club_staff_permissions where club_id=p_club and profile_id=auth.uid() for share;
end $$;

drop function if exists public.my_club_operations_authority();
create function public.my_club_operations_authority()
returns table(club_id uuid,inventory_read boolean,inventory_write boolean,health_read boolean,planning_read boolean,administrative_write boolean)
language sql stable security definer set search_path=public,pg_temp as $$
 select distinct m.club_id,public._inventory_read(m.club_id),public._inventory_write(m.club_id),public._club_health_read(m.club_id),
 public._club_active_staff(m.club_id) or public._club_specialist(m.club_id,array['sporting_director','president']),
 exists(select 1 from club_memberships own_membership where own_membership.club_id=m.club_id and own_membership.profile_id=auth.uid() and own_membership.status='active' and own_membership.role in ('coach','club_admin'))
  or public._club_specialist(m.club_id,array['president'])
 from club_memberships m where m.profile_id=auth.uid() and m.status='active'
$$;
create or replace function public.club_health_operations(p_club uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$ begin
 if not public._club_health_read(p_club) then raise exception 'Sağlık/idari kulüp yetkisi gerekli' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('athlete_id',a.id,'reference',public.athlete_ref(a.id),
  'status',g.status,'blocked',g.blocked,'reason',g.reason_label,'rest_status',case when public._club_rest_active(a.id) then r.status end,
  'restriction_id',case when public.is_authorized_health_officer(p_club) then (select h.id from health_restrictions h where h.athlete_id=a.id and h.status in ('restricted','under_review') limit 1) end))
  from athletes a cross join lateral public.eligibility_gate(a.id) g left join club_athlete_rest r on r.athlete_id=a.id where a.club_id=p_club),'[]'::jsonb);
end $$;
create or replace function public.club_sporting_overview(p_club uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$ begin
 if not (public._club_active_staff(p_club) or public._club_specialist(p_club,array['sporting_director','president'])) then raise exception 'Sportif kulüp yetkisi gerekli' using errcode='42501'; end if;
 return jsonb_build_object('athletes',(select count(*) from athletes where club_id=p_club),
 'expiring_licenses',(select count(*) from athlete_sport_registrations where club_id=p_club and expires_on between current_date and current_date+30),
 'licenses',coalesce((select jsonb_agg(to_jsonb(q)) from (select public.athlete_ref(r.athlete_id) reference,r.sport_code,r.expires_on from athlete_sport_registrations r
  where r.club_id=p_club and r.expires_on between current_date and current_date+30 order by r.expires_on,r.athlete_id,r.sport_code limit 50) q),'[]'::jsonb),
 'completed_transfers',(select count(*) from athlete_transfers where (from_club_id=p_club or to_club_id=p_club) and transferred_on>=current_date-30),
 'locked_lineups',(select count(*) from match_lineup_approvals a join org_participants p on p.id=a.participant_id where p.club_id=p_club and a.verified_at>=clock_timestamp()-interval '30 days'),
 'attendance',coalesce((select jsonb_build_object('present',count(*) filter(where at.status='present'),'late',count(*) filter(where at.status='late'),
  'absent',count(*) filter(where at.status='absent'),'excused',count(*) filter(where at.status='excused')) from attendance at join events e on e.id=at.event_id
  where at.club_id=p_club and e.club_id=p_club and e.starts_at between clock_timestamp()-interval '30 days' and clock_timestamp()),'{}'::jsonb),
 'teams',coalesce((select jsonb_agg(jsonb_build_object('id',t.id,'name',t.name,'athlete_count',(select count(distinct tm.athlete_id) from team_memberships tm
  join athletes ath on ath.id=tm.athlete_id and ath.club_id=t.club_id where tm.team_id=t.id))) from teams t where t.club_id=p_club),'[]'::jsonb));
end $$;

-- Broaden only the two development-report RPCs, not the general performance,
-- nutrition, medical or athlete-table policies. Scope still uses active membership.
do $$ declare def text;begin
 def:=pg_get_functiondef('public.development_report_athletes(text,int)'::regprocedure);
 if position('_club_specialist' in def)=0 then
  if position('public.can_view_athlete_performance(a.id)' in def)=0 then raise exception 'Report picker contract changed'; end if;
  def:=replace(def,'public.can_view_athlete_performance(a.id)',
   '(public.can_view_athlete_performance(a.id) or public._club_specialist(a.club_id,array[''sporting_director'',''president'']))');execute def;
 end if;
 def:=pg_get_functiondef('public.athlete_development_report(uuid,date,date)'::regprocedure);
 if position('_club_specialist' in def)=0 then
  if position('public.can_view_athlete_performance(p_athlete)' in def)=0 then raise exception 'Report access contract changed'; end if;
  def:=replace(def,'public.can_view_athlete_performance(p_athlete)',
   '(public.can_view_athlete_performance(p_athlete) or exists(select 1 from public.athletes club_athlete where club_athlete.id=p_athlete and public._club_specialist(club_athlete.club_id,array[''sporting_director'',''president''])))');execute def;
 end if;
end $$;

-- Existing clinical RPC stays authoritative. A permitted physician who is an
-- active ordinary member need not also be coach/admin to open a restriction.
do $$ declare def text;begin
 def:=pg_get_functiondef('public.open_health_restriction(uuid,text,timestamptz,uuid)'::regprocedure);
 if position('_club_health_read(v_club)' in def)=0 then
  def:=replace(def,'if not public.is_club_staff(v_club) then','if not public._club_health_read(v_club) then');execute def;end if;
 def:=pg_get_functiondef('public.open_health_restriction(uuid,text,timestamptz,uuid)'::regprocedure);
 if position('_club_operation_actor_lock' in def)=0 then
  if position('if p_status not in' in def)=0 then raise exception 'Clinical open contract changed';end if;
  def:=replace(def,'if p_status not in','perform public._club_operation_actor_lock(v_club); perform 1 from public.athletes where id=p_athlete and club_id=v_club for share; if not found then raise exception ''Sporcu kulübü değişti'' using errcode=''40001'';end if; if p_status is null or p_status not in');execute def;
 end if;
 def:=pg_get_functiondef('public.open_health_restriction(uuid,text,timestamptz,uuid)'::regprocedure);
 if position('reevaluation_date is not distinct from p_reevaluation' in def)=0 then
  def:=replace(def,'insert into public.health_restrictions',
   'select id into v_id from public.health_restrictions where athlete_id=p_athlete and status=p_status and created_by=auth.uid() and reevaluation_date is not distinct from p_reevaluation and evidence_ref is not distinct from p_evidence; if v_id is not null then return v_id;end if; insert into public.health_restrictions');execute def;
 end if;
 def:=pg_get_functiondef('public.clear_health_restriction(uuid,text)'::regprocedure);
 if position('_club_operation_actor_lock' in def)=0 then
  if position('if not public.is_authorized_health_officer(v_r.club_id)' in def)=0 then raise exception 'Clinical clear contract changed';end if;
  def:=replace(def,'if not public.is_authorized_health_officer(v_r.club_id)',
   'perform public._club_operation_actor_lock(v_r.club_id); if not public.is_authorized_health_officer(v_r.club_id)');
  -- Signature remains compatible; new audit entries contain authority/action,
  -- never the caller's clinical narrative. Existing historical JSON is not erased.
  def:=replace(def,'''action'', ''clear'', ''note'', p_note','''action'', ''clear''');execute def;
 end if;
 def:=pg_get_functiondef('public.clear_health_restriction(uuid,text)'::regprocedure);
 if position('v_r.status=''cleared''' in def)=0 then
  def:=replace(def,'if coalesce(trim(coalesce(p_note','if v_r.status=''cleared'' then return;end if; if coalesce(trim(coalesce(p_note');execute def;
 end if;
 def:=pg_get_functiondef('public.eligibility_gate(uuid)'::regprocedure);
 if position('_club_rest_active' in def)=0 then
  def:=replace(def,'(exists (select 1 from active_restriction where status = ''restricted'')','(public._club_rest_active(p_athlete) or exists (select 1 from active_restriction where status = ''restricted'')');
  def:=replace(def,'else ''eligible''','when public._club_rest_active(p_athlete) then ''restricted'' else ''eligible''');
  def:=replace(def,'else ''ok''','when public._club_rest_active(p_athlete) then ''administrative_rest'' else ''ok''');
  def:=replace(def,'else ''Uygun''','when public._club_rest_active(p_athlete) then ''İdari dinlenme'' else ''Uygun''');execute def;
 end if;
 def:=pg_get_functiondef('public.referee_lineup_candidates(uuid)'::regprocedure);
 if position('_club_rest_active' in def)=0 then
  def:=replace(def,'when exists(select 1 from public.eligibility_gate(a.id)','when public._club_rest_active(a.id) and not exists(select 1 from public.health_restrictions h where h.athlete_id=a.id and h.status=''restricted'') then ''rested'' when exists(select 1 from public.eligibility_gate(a.id)');
  def:=replace(def,'not exists(select 1 from public.eligibility_gate(a.id)','not public._club_rest_active(a.id) and not exists(select 1 from public.eligibility_gate(a.id)');execute def;
 end if;
 def:=pg_get_functiondef('public._sports_roster_validate(uuid,uuid[],uuid[])'::regprocedure);
 if position('_club_rest_active' in def)=0 then
  def:=replace(def,'perform public._c1_require_athlete','if public._club_rest_active(a) then raise exception ''İdari dinlenme aktif'' using errcode=''22023'';end if; perform public._c1_require_athlete');execute def;
 end if;
 def:=pg_get_functiondef('public.referee_append_match_event(uuid,uuid,integer,text,text,uuid,uuid,text)'::regprocedure);
 if position('_club_rest_active' in def)=0 then
  def:=replace(def,'or public._disciplinary_suspended(p_replacement_id','or public._club_rest_active(p_replacement_id) or public._disciplinary_suspended(p_replacement_id');execute def;
 end if;
end $$;

revoke all on function public._club_operation_actor_lock(uuid),public._club_active_staff(uuid),public._club_specialist(uuid,text[]),public._inventory_require(uuid),public._club_rest_active(uuid),public._club_health_read(uuid) from public,anon,authenticated;
revoke all on function public._inventory_read(uuid),public._inventory_write(uuid) from public,anon;
grant execute on function public._inventory_read(uuid),public._inventory_write(uuid) to authenticated;
revoke all on function public.inventory_add_item(uuid,uuid,text,text,int,text),public.inventory_assign(uuid,uuid,int,uuid,uuid,text),
 public.inventory_return(uuid,text),public.club_inventory_board(uuid),public.my_club_operations_authority(),public.set_club_athlete_rest(uuid,text,timestamptz),
 public.club_health_operations(uuid),public.club_sporting_overview(uuid) from public,anon;
grant execute on function public.inventory_add_item(uuid,uuid,text,text,int,text),public.inventory_assign(uuid,uuid,int,uuid,uuid,text),
 public.inventory_return(uuid,text),public.club_inventory_board(uuid),public.my_club_operations_authority(),public.set_club_athlete_rest(uuid,text,timestamptz),
 public.club_health_operations(uuid),public.club_sporting_overview(uuid) to authenticated;
insert into public.feature_flags(key,audience,label) values('club_staff_operations','admins','Kulüp ihtisas operasyonları') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,audience,feature,route,sort_order)
 select 'Malzeme zimmeti ve idari dinlendirme nasıl yönetilir?',
 'Profil > Yönetim altında kulüp ihtisas modüllerini açın. Malzeme sorumlusu ve yönetici stoktan üye veya takıma zimmet verir; iade, hasarlı ve eksik miktarlar ayrı izlenir. Hesapsız sporcular için takım hedefi kullanılır. Doktorsuz kulüpte antrenör/yönetici idari dinlendirir. Yetkili hekim tıbbi kilidi yönetir; idari dinlendirmeyi kaldırmak tıbbi kilidi kaldırmaz. Muhasebecilik tek başına bu özel kayıtları açmaz.',
 'Kulüp','club_staff','club_staff_operations','/kulup/malzeme-zimmet',114
 where not exists(select 1 from public.faq_entries where feature='club_staff_operations' and active);
