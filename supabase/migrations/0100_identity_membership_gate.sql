-- Phase C1. Apply after the committed 0099, in a separate transaction.
set local lock_timeout = '15s';

-- Old declared TCKNs never become verified identities by backfill.
alter table public.profile_credentials add column if not exists verified_national_id text;
create unique index if not exists credential_verified_national_unique
 on public.profile_credentials(verified_national_id) where verified_national_id is not null;
create unique index if not exists credential_identity_account_unique
 on public.profile_credentials(profile_id) where kind='identity';
do $$ begin
 alter table public.profile_credentials add constraint credential_identity_value check(
  (kind='identity' and sport_code is null and coach_level is null and expires_on is null
   and (verified_national_id is null or verified_national_id ~ '^[1-9][0-9]{10}$')
   and (status<>'approved' or verified_national_id is not null))
  or (kind<>'identity' and verified_national_id is null));
exception when duplicate_object then null;end $$;

-- Immutable, one-time migration snapshot, never a rolling "all members" exemption.
do $$ begin
 if not exists(select 1 from information_schema.columns where table_schema='public'
  and table_name='club_memberships' and column_name='identity_gate_legacy') then
  alter table public.club_memberships add column identity_gate_legacy boolean not null default false;
  update public.club_memberships set identity_gate_legacy=true where status='active';
 end if;
 if not exists(select 1 from information_schema.columns where table_schema='public'
  and table_name='guardians' and column_name='identity_gate_legacy') then
  alter table public.guardians add column identity_gate_legacy boolean not null default false;
  update public.guardians set identity_gate_legacy=true where profile_id is not null;
 end if;
end $$;

-- 0009 historically relaxed this column. Never manufacture clubs or delete old
-- independent records to conceal that conflict: fail the whole file for review.
do $$ begin
 if exists(select 1 from public.athletes where club_id is null) then
  raise exception 'C1 preflight: eski kulüpsüz sporcu kayıtları manuel incelenmeli; veri değiştirilmedi';
 end if;
end $$;
alter table public.athletes alter column club_id set not null;

create or replace function public._c1_has_identity(p_profile uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profile_credentials c where c.profile_id=p_profile
  and c.kind='identity' and c.status='approved' and c.verified_national_id is not null)
$$;
create or replace function public._c1_require_identity(p_profile uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 perform 1 from public.profile_credentials c where c.profile_id=p_profile and c.kind='identity'
  and c.status='approved' and c.verified_national_id is not null for share;
 if not found then
  raise exception 'Doğrulanmış kimlik gerekli; hesap bekleme odasında' using errcode='42501';
 end if;
end $$;
create or replace function public._c1_actor_for_club(p_club uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is not null and public._c1_has_identity(auth.uid()) then
  perform public._c1_require_identity(auth.uid());return;
 end if;
 perform 1 from public.club_memberships m where m.club_id=p_club and m.profile_id=auth.uid()
  and m.status='active' and m.identity_gate_legacy for share;
 if not found then
  raise exception 'Doğrulanmış kimlik veya mevcut kulüpte geçiş hakkı gerekli' using errcode='42501';
 end if;
end $$;
create or replace function public._c1_has_sport(p_profile uuid,p_sport text,p_role text)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profile_credentials c where c.profile_id=p_profile
  and c.sport_code=p_sport and c.status='approved'
  and (c.expires_on is null or c.expires_on>=(now() at time zone 'Europe/Istanbul')::date)
  and case when p_role in ('coach','club_admin') then c.kind='coach'
   when p_role='athlete' then c.kind in ('athlete_licensed','athlete_individual')
   else c.kind in ('coach','athlete_licensed','athlete_individual') end)
$$;
create or replace function public._c1_live_guardian(p_athlete uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.guardians g where g.athlete_id=p_athlete
  and g.profile_id is not null and public._c1_has_identity(g.profile_id)
  and (g.identity_gate_legacy or exists(select 1 from public.invite_codes i
    where i.purpose='guardian_link' and i.athlete_id=g.athlete_id
     and i.used_by=g.profile_id and i.used_at is not null)))
$$;
-- Keep consent revocation and identity review serialized with new grants.
create or replace function public._c1_require_guardian(p_athlete uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 perform 1 from public.guardians g join public.profile_credentials c on c.profile_id=g.profile_id
  and c.kind='identity' and c.status='approved' and c.verified_national_id is not null
 where g.athlete_id=p_athlete and (g.identity_gate_legacy or exists(
  select 1 from public.invite_codes i where i.purpose='guardian_link' and i.athlete_id=g.athlete_id
   and i.used_by=g.profile_id and i.used_at is not null)) for share of g,c;
 if not found then raise exception 'Doğrulanmış veli bağı gerekli';end if;
end $$;
create or replace function public._c1_require_sport(p_profile uuid,p_sport text,p_role text)
returns void language plpgsql security definer set search_path=public as $$
begin
 perform 1 from public.profile_credentials c where c.profile_id=p_profile and c.sport_code=p_sport
  and c.status='approved' and (c.expires_on is null or c.expires_on>=(now() at time zone 'Europe/Istanbul')::date)
  and case when p_role in ('coach','club_admin') then c.kind='coach'
   when p_role='athlete' then c.kind in ('athlete_licensed','athlete_individual')
   else c.kind in ('coach','athlete_licensed','athlete_individual') end for share;
 if not found then raise exception 'Bu branşta geçerli onaylı belge gerekli' using errcode='42501';end if;
end $$;
create or replace function public._c1_require_member(p_profile uuid,p_club uuid,p_role text,p_team uuid,p_level int)
returns void language plpgsql security definer set search_path=public as $$
declare v_sport text;v_child uuid;
begin
 perform public._c1_require_identity(p_profile);
 select coalesce(t.sport_code,c.sport_code) into v_sport from public.clubs c
 left join public.teams t on t.id=p_team and t.club_id=c.id where c.id=p_club;
 if p_team is not null and not exists(select 1 from public.teams t where t.id=p_team and t.club_id=p_club) then
  raise exception 'Takım kulübü uyuşmuyor';end if;
 if p_role='parent' then
  if not exists(select 1 from public.guardians g join public.athletes a on a.id=g.athlete_id
   where g.profile_id=p_profile and a.club_id=p_club and public._c1_live_guardian(a.id)) then
   raise exception 'Veli için doğrulanmış kimlik ve geçerli davet bağı gerekli';end if;
  perform public._c1_require_guardian(g.athlete_id) from public.guardians g join public.athletes a on a.id=g.athlete_id
   where g.profile_id=p_profile and a.club_id=p_club and public._c1_live_guardian(a.id);
  if p_team is not null or p_level is not null then raise exception 'Veli takım/antrenör atanamaz';end if;
  return;
 end if;
 -- The existing create_club API has no sport argument. Its pending bootstrap
 -- may create only its own admin membership, with a valid >=2 sport credential.
 if v_sport is null and p_role='club_admin' and p_profile=auth.uid() and exists(
  select 1 from public.clubs c where c.id=p_club and c.created_by=p_profile and c.status='pending')
  and exists(select 1 from public.profile_credentials c where c.profile_id=p_profile
   and c.kind='coach' and c.status='approved' and c.sport_code is not null and c.coach_level>=2
   and (c.expires_on is null or c.expires_on>=(now() at time zone 'Europe/Istanbul')::date)) then return;end if;
 perform public._c1_require_sport(p_profile,v_sport,p_role);
 if p_role='coach' and (p_level is null or p_level<1 or p_level>public.coach_level_for_sport(p_profile,v_sport)) then
  raise exception 'Antrenör kademesi onaylı branş belgesini aşamaz';end if;
 if p_role='athlete' then
  for v_child in select a.id from public.athletes a where a.profile_id=p_profile and a.club_id=p_club
   and (a.birth_date is null or a.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date) loop
   perform public._c1_require_guardian(v_child);
  end loop;
 end if;
end $$;
create or replace function public._c1_require_athlete(p_athlete uuid,p_club uuid,p_sport text)
returns void language plpgsql security definer set search_path=public as $$
declare a public.athletes;
begin
 select * into a from public.athletes where id=p_athlete and club_id=p_club;
 if not found then raise exception 'Sporcu/kulüp uyuşmuyor';end if;
 if a.profile_id is not null then
  -- Preserve established members in their existing club, not future memberships.
  if not exists(select 1 from public.club_memberships m where m.club_id=p_club
    and m.profile_id=a.profile_id and m.role='athlete' and m.status='active' and m.identity_gate_legacy
    and p_sport=(select sport_code from public.clubs where id=p_club)) then
   perform public._c1_require_member(a.profile_id,p_club,'athlete',null,null);
   perform public._c1_require_sport(a.profile_id,p_sport,'athlete');
  end if;
 else
  if not exists(select 1 from public.athlete_sport_registrations r where r.athlete_id=a.id
   and r.sport_code=p_sport and r.club_id=p_club
   and r.expires_on>=(now() at time zone 'Europe/Istanbul')::date) then
   raise exception 'Hesapsız sporcu için branş lisans kaydı gerekli';end if;
  if (a.birth_date is null or a.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date) then
   perform public._c1_require_guardian(a.id);end if;
 end if;
end $$;

-- The shared legacy trigger remains intact except identity documents have no
-- sport or expiry. Separate review validation below governs new sport approvals.
create or replace function public._federation_new_row_rules() returns trigger language plpgsql security definer set search_path=public as $$
declare s text;
begin
 if tg_table_name='profile_credentials' then
  if new.kind='identity' then return new;end if;
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


-- Direct clients cannot review credentials or consume/forge invitations. The
-- existing definer RPCs retain their owner privileges; no extra public writer.
revoke update,delete on public.profile_credentials from public,anon,authenticated;
revoke update on public.invite_codes from public,anon,authenticated;
create or replace function public._c1_credential_guard()
returns trigger language plpgsql set search_path=public as $$
begin
 if tg_op='INSERT' then
  if new.status<>'pending' or new.reviewed_at is not null or new.reviewed_by is not null
    or new.verified_national_id is not null then raise exception 'İnceleme yalnız yetkili RPC ile yapılır';end if;
 else
  if pg_trigger_depth()>1 and new.reviewed_by is null and
   (to_jsonb(new)-'reviewed_by')=(to_jsonb(old)-'reviewed_by') then return new;end if;
  if (new.profile_id,new.kind) is distinct from(old.profile_id,old.kind) then raise exception 'Belge sahibi/türü değiştirilemez';end if;
  if (new.status,new.reviewed_at,new.reviewed_by,new.verified_national_id) is distinct from
   (old.status,old.reviewed_at,old.reviewed_by,old.verified_national_id)
   and (current_user in ('anon','authenticated') or not public.is_platform_admin()) then
   raise exception 'İnceleme yalnız platform yöneticisi RPC ile yapılır';end if;
  if new.kind<>'identity' and new.status='approved' and
   (old.status<>'approved' or (new.sport_code,new.coach_level) is distinct from(old.sport_code,old.coach_level))
   and (new.expires_on is null or new.expires_on<(now() at time zone 'Europe/Istanbul')::date or new.sport_code is null) then
   raise exception 'Yeni onay için branş ve geçerli bitiş tarihi zorunlu';end if;
 end if;
 return new;
end $$;
drop trigger if exists c1_credential_guard on public.profile_credentials;
create trigger c1_credential_guard before insert or update on public.profile_credentials
 for each row execute function public._c1_credential_guard();

-- A user-editable profiles flag cannot promote its owner into the reviewer role.
create or replace function public._c1_profile_admin_guard()
returns trigger language plpgsql set search_path=public as $$
begin
 if current_user in ('anon','authenticated') then
  if (tg_op='INSERT' and new.is_platform_admin)
   or (tg_op='UPDATE' and new.is_platform_admin is distinct from old.is_platform_admin) then
   raise exception 'Platform yetkisi kullanıcı tarafından değiştirilemez';end if;
 end if;
 return new;
end $$;
drop trigger if exists c1_profile_admin_guard on public.profiles;
create trigger c1_profile_admin_guard before insert or update on public.profiles
 for each row execute function public._c1_profile_admin_guard();

-- Replace the existing review endpoint, eliminating every historical overload.
drop function if exists public.review_credential(uuid,boolean,text);
drop function if exists public.review_credential(uuid,boolean,text,int,text);
drop function if exists public.review_credential(uuid,boolean,text,int,text,text,date);
create function public.review_credential(p_cred uuid,p_approve boolean,p_note text default null,
 p_coach_level int default null,p_sport_code text default null,p_national_id text default null,p_expires_on date default null)
returns void language plpgsql security definer set search_path=public as $$
declare c public.profile_credentials;v_national text;
begin
 if not public.is_platform_admin() then raise exception 'Yetkisiz' using errcode='42501';end if;
 if p_approve is null then raise exception 'İnceleme kararı gerekli';end if;
 select * into c from public.profile_credentials where id=p_cred for update;
 if not found then raise exception 'Başvuru bulunamadı';end if;
 if c.kind='identity' then
  if p_approve then
   v_national:=coalesce(nullif(trim(p_national_id),''),c.verified_national_id);
   if v_national is null or v_national !~ '^[1-9][0-9]{10}$' then raise exception 'İncelenmiş TCKN gerekli';end if;
   if c.verified_national_id is not null and c.verified_national_id<>v_national then raise exception 'Doğrulanmış TCKN değiştirilemez';end if;
   if not exists(select 1 from public.verification_documents d where d.owner_type='credential'
    and d.owner_id=c.id and d.uploaded_by=c.profile_id and d.doc_type='kimlik'
    and d.storage_path like c.profile_id::text||'/%') then raise exception 'Mevcut belge sisteminde kimlik belgesi gerekli';end if;
  else v_national:=c.verified_national_id;end if;
  update public.profile_credentials set verified_national_id=v_national,
   status=(case when p_approve then 'approved' else 'rejected' end)::public.verification_status,
   reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),note=p_note where id=c.id;
 else
  if p_national_id is not null then raise exception 'TCKN yalnız kimlik incelemesinde yazılır';end if;
  update public.profile_credentials set
   status=(case when p_approve then 'approved' else 'rejected' end)::public.verification_status,
   coach_level=coalesce(p_coach_level,coach_level),sport_code=coalesce(p_sport_code,sport_code),
   expires_on=coalesce(p_expires_on,expires_on),reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),note=p_note where id=c.id;
 end if;
end $$;
revoke all on function public.review_credential(uuid,boolean,text,int,text,text,date) from public,anon,authenticated;
grant execute on function public.review_credential(uuid,boolean,text,int,text,text,date) to authenticated;

-- Guards cover old RPCs AND direct writes, without changing read RLS.
create or replace function public._c1_membership_guard()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_sport text;
begin
 if tg_op='INSERT' then
  if new.identity_gate_legacy then raise exception 'Geçiş hakkı istemciden verilemez';end if;
 else
  if new.identity_gate_legacy and not old.identity_gate_legacy then raise exception 'Geçiş hakkı üretilemez';end if;
  if new.club_id is distinct from old.club_id then perform public._c1_actor_for_club(old.club_id);end if;
  if (new.club_id,new.profile_id,new.role,new.team_id,new.coach_level,new.supervisor_id,new.status)
    is not distinct from(old.club_id,old.profile_id,old.role,old.team_id,old.coach_level,old.supervisor_id,old.status) then return new;end if;
  if (new.club_id,new.profile_id,new.role,new.team_id,new.coach_level,new.supervisor_id) is distinct from
     (old.club_id,old.profile_id,old.role,old.team_id,old.coach_level,old.supervisor_id) or new.status<>'active' then
   new.identity_gate_legacy:=false;
  end if;
 end if;
 perform public._c1_actor_for_club(new.club_id);
 if new.status='active' then
  if tg_op='UPDATE' and old.identity_gate_legacy and new.identity_gate_legacy then return new;end if;
  if new.role='coach' and new.coach_level is null then
   select coalesce(t.sport_code,c.sport_code) into v_sport from public.clubs c
    left join public.teams t on t.id=new.team_id and t.club_id=c.id where c.id=new.club_id;
   new.coach_level:=public.coach_level_for_sport(new.profile_id,v_sport);
  end if;
  perform public._c1_require_member(new.profile_id,new.club_id,new.role::text,new.team_id,new.coach_level);
 end if;
 return new;
end $$;
drop trigger if exists c1_membership_guard on public.club_memberships;
create trigger c1_membership_guard before insert or update on public.club_memberships
 for each row execute function public._c1_membership_guard();

create or replace function public._c1_team_guard()
returns trigger language plpgsql security definer set search_path=public as $$
declare c uuid;s text;a uuid;
begin
 if tg_table_name='teams' then
  perform public._c1_actor_for_club(new.club_id);
  if tg_op='UPDATE' then
   if new.club_id is distinct from old.club_id then perform public._c1_actor_for_club(old.club_id);end if;
   if (new.club_id,new.sport_code) is distinct from(old.club_id,old.sport_code) and
    (exists(select 1 from public.team_memberships tm where tm.team_id=old.id)
     or exists(select 1 from public.club_memberships m where m.team_id=old.id)) then
    raise exception 'Atanmış takımın kulüp/branşı değiştirilemez';end if;
  end if;
  return new;
 end if;
 select t.club_id,coalesce(t.sport_code,cl.sport_code) into c,s from public.teams t
  join public.clubs cl on cl.id=t.club_id where t.id=new.team_id;
 perform public._c1_actor_for_club(c);
 if tg_op='UPDATE' and (new.team_id,new.athlete_id,new.season_id) is not distinct from(old.team_id,old.athlete_id,old.season_id) then return new;end if;
 perform public._c1_require_athlete(new.athlete_id,c,s);
 return new;
end $$;
drop trigger if exists c1_team_guard on public.teams;
create trigger c1_team_guard before insert or update on public.teams for each row execute function public._c1_team_guard();
drop trigger if exists c1_team_member_guard on public.team_memberships;
create trigger c1_team_member_guard before insert or update on public.team_memberships for each row execute function public._c1_team_guard();

create or replace function public._c1_guardian_guard()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='INSERT' then
  if new.identity_gate_legacy then raise exception 'Eski veli bağı üretilemez';end if;
 else
  if new.identity_gate_legacy and not old.identity_gate_legacy then raise exception 'Eski veli bağı üretilemez';end if;
  if (new.athlete_id,new.profile_id) is not distinct from(old.athlete_id,old.profile_id) then return new;end if;
  new.identity_gate_legacy:=false;
  -- FK cleanup must not prevent account deletion; lifecycle redesign is separate.
  if pg_trigger_depth()>1 and new.profile_id is null then return new;end if;
 end if;
 if new.profile_id is not null then
  perform public._c1_require_identity(new.profile_id);
  if not exists(select 1 from public.invite_codes i where i.purpose='guardian_link'
   and i.athlete_id=new.athlete_id and i.used_by=new.profile_id and i.used_at is not null) then
   raise exception 'Veli bağı için geçerli tüketilmiş davet gerekli';end if;
 else
  perform public._c1_actor_for_club((select club_id from public.athletes where id=new.athlete_id));
 end if;
 return new;
end $$;
drop trigger if exists c1_guardian_guard on public.guardians;
create trigger c1_guardian_guard before insert or update on public.guardians for each row execute function public._c1_guardian_guard();

create or replace function public._c1_invite_guard()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='INSERT' and (new.used_at is not null or new.used_by is not null) then raise exception 'Tüketilmiş davet üretilemez';end if;
 if tg_op='UPDATE' and old.used_at is not null then
  if (new.purpose,new.athlete_id,new.created_by,new.used_at,new.used_by,new.code) is distinct from
   (old.purpose,old.athlete_id,old.created_by,old.used_at,old.used_by,old.code) then raise exception 'Tüketilmiş davet değiştirilemez';end if;
 end if;
 if new.purpose='guardian_link' and tg_op='INSERT' then
  if new.created_by is distinct from auth.uid() or not exists(select 1 from public.athletes a
   join public.club_memberships m on m.club_id=a.club_id where a.id=new.athlete_id
    and m.profile_id=auth.uid() and m.status='active' and m.role in ('club_admin','coach','official')) then
   raise exception 'Veli daveti yalnız sporcunun kulüp yetkilisinden';end if;
  perform public._c1_actor_for_club((select club_id from public.athletes where id=new.athlete_id));
 end if;
 return new;
end $$;
drop trigger if exists c1_invite_guard on public.invite_codes;
create trigger c1_invite_guard before insert or update on public.invite_codes for each row execute function public._c1_invite_guard();

-- Boolean/state only, never verified TCKN in the general profile payload.
create or replace function public.my_identity_gate()
returns jsonb language sql stable security definer set search_path=public as $$
 select jsonb_build_object('identity_verified',public._c1_has_identity(auth.uid()),
  'legacy_club_ids',coalesce((select jsonb_agg(distinct m.club_id) from public.club_memberships m
   where m.profile_id=auth.uid() and m.status='active' and m.identity_gate_legacy),'[]'::jsonb))
$$;
revoke all on function public.my_identity_gate() from public,anon,authenticated;
grant execute on function public.my_identity_gate() to authenticated;

-- Existing endpoint bodies with additive entry checks.
create or replace function public.create_club(
  p_name       text,
  p_short_name text default null,
  p_city       text default null
)
returns public.clubs
language plpgsql security definer set search_path = public as $$
declare v_club public.clubs;
begin
  perform public._c1_require_identity(auth.uid());
  if not exists(select 1 from public.profile_credentials c where c.profile_id=auth.uid() and c.kind='coach'
   and c.status='approved' and c.sport_code is not null and c.coach_level>=2
   and (c.expires_on is null or c.expires_on>=(now() at time zone 'Europe/Istanbul')::date)) then
   raise exception 'Geçerli branşlı en az ikinci kademe belge gerekli';end if;
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  -- Kurucu şartı: ≥2. kademe onaylı antrenör kimliği
  if not exists (
    select 1 from public.profile_credentials
    where profile_id = auth.uid()
      and kind = 'coach'
      and coalesce(coach_level, 0) >= 2
      and status = 'approved'
  ) then
    raise exception 'Kulüp kurmak için en az 2. kademe doğrulanmış antrenör olmalısın.';
  end if;

  insert into public.clubs (name, short_name, city, created_by, status)
  values (p_name, p_short_name, p_city, auth.uid(), 'pending')
  returning * into v_club;

  insert into public.club_memberships (club_id, profile_id, role, status)
  values (v_club.id, auth.uid(), 'club_admin', 'active');

  return v_club;
end;
$$;
create or replace function public.apply_to_club(
  p_club uuid,
  p_role text default 'athlete',
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_role not in ('coach','athlete') or p_role is null then raise exception 'Başvuru rolü geçersiz';end if;
  perform public._c1_require_member(auth.uid(),p_club,p_role,null,
    case when p_role='coach' then public.coach_level_for_sport(auth.uid(),(select sport_code from public.clubs where id=p_club)) end);
  if auth.uid() is null then
    raise exception 'Oturum bulunamadı';
  end if;

  -- Kimliği onaylanmamış kişi başvuramaz.
  if not exists (
    select 1 from public.profile_credentials c
    where c.profile_id = auth.uid() and c.status = 'approved'
  ) then
    raise exception 'Önce kimliğini doğrulatmalısın';
  end if;

  -- Kulüp aktif olmalı.
  if not exists (
    select 1 from public.clubs c where c.id = p_club and c.status = 'active'
  ) then
    raise exception 'Kulüp bulunamadı veya henüz onaylanmamış';
  end if;

  -- Zaten üyeyse başvurmasın.
  if exists (
    select 1 from public.club_memberships m
    where m.club_id = p_club and m.profile_id = auth.uid()
      and m.status = 'active'
  ) then
    raise exception 'Bu kulübün zaten üyesisin';
  end if;

  insert into public.club_applications (club_id, profile_id, desired_role, message)
  values (p_club, auth.uid(), coalesce(p_role, 'athlete'), p_message)
  on conflict do nothing
  returning id into v_id;

  if v_id is null then
    raise exception 'Bu kulübe bekleyen bir başvurun zaten var';
  end if;

  return v_id;
end;
$$;
create or replace function public.offer_to_person(
  p_club uuid,
  p_profile uuid,
  p_role text default 'athlete',
  p_message text default null
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public._c1_actor_for_club(p_club);
  if not public.can_review_club_applications(p_club) then
    raise exception 'Bu kulüp adına teklif sunma yetkin yok';
  end if;

  if exists (
    select 1 from public.club_memberships m
    where m.club_id = p_club and m.profile_id = p_profile and m.status = 'active'
  ) then
    raise exception 'Bu kişi zaten kulübün üyesi';
  end if;

  insert into public.club_applications
    (club_id, profile_id, desired_role, message, kind, created_by)
  values (p_club, p_profile, coalesce(p_role,'athlete'), p_message, 'offer', auth.uid())
  on conflict do nothing
  returning id into v_id;

  if v_id is null then
    raise exception 'Bu kişiye bekleyen bir teklifin/başvurun zaten var';
  end if;
  return v_id;
end; $$;
drop function if exists public.review_club_application(uuid,boolean,text);
create or replace function public.review_club_application(
  p_application uuid,
  p_accept boolean,
  p_note text default null,
  p_coach_level int default null,
  p_supervisor uuid default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_app public.club_applications%rowtype;
  v_level int;
  v_sup uuid;
begin
  select * into v_app from public.club_applications where id = p_application for update;
  if not found then raise exception 'Başvuru bulunamadı'; end if;
  if v_app.status<>'pending' then raise exception 'Başvuru zaten incelenmiş';end if;
  if p_accept then
   perform public._c1_actor_for_club(v_app.club_id);
   perform public._c1_require_member(v_app.profile_id,v_app.club_id,v_app.desired_role,null,
    case when v_app.desired_role='coach' then coalesce(p_coach_level,v_app.coach_level,public.coach_level_for_sport(v_app.profile_id,(select sport_code from public.clubs where id=v_app.club_id))) end);
  end if;

  -- Yetki: teklifi hedef kişi, başvuruyu kulüp yetkilisi yanıtlar.
  if v_app.kind = 'offer' then
    if v_app.profile_id <> auth.uid() then
      raise exception 'Bu teklifi yanıtlama yetkin yok';
    end if;
  else
    if not public.can_review_club_applications(v_app.club_id) then
      raise exception 'Bu başvuruyu inceleme yetkin yok';
    end if;
  end if;

  update public.club_applications
     set status = case when p_accept then 'accepted' else 'rejected' end,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         review_note = p_note
   where id = p_application;

  if p_accept then
    v_level := coalesce(p_coach_level, v_app.coach_level);
    v_sup   := coalesce(p_supervisor,  v_app.supervisor_id);

    insert into public.club_memberships
      (club_id, profile_id, role, status, coach_level, supervisor_id)
    values (
      v_app.club_id,
      v_app.profile_id,
      (case when v_app.desired_role = 'coach' then 'coach' else 'athlete' end)
        ::public.club_role,
      'active',
      case when v_app.desired_role = 'coach' then v_level else null end,
      case when v_app.desired_role = 'coach' then v_sup else null end
    )
    on conflict do nothing;
  end if;
end; $$;
create or replace function public.create_guardian_invite(p_athlete uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_code text; v_club uuid;
begin
  perform public._c1_actor_for_club((select club_id from public.athletes where id=p_athlete));
  select club_id into v_club from public.athletes where id = p_athlete;
  if v_club is null or not public.is_club_staff(v_club) then
    raise exception 'Yetkisiz veya sporcu bulunamadı';
  end if;
  v_code := upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  insert into public.invite_codes (code, athlete_id, created_by)
  values (v_code, p_athlete, auth.uid());
  return v_code;
end; $$;
create or replace function public.redeem_invite_code(p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare v_inv public.invite_codes; v_name text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_inv from public.invite_codes
    where code = upper(p_code) and used_at is null and expires_at > now()
    limit 1 for update;
  if v_inv.id is null or v_inv.expires_at<=clock_timestamp() then raise exception 'Kod geçersiz veya süresi dolmuş'; end if;

  if v_inv.target_email is not null then
    if lower((select email from auth.users where id = auth.uid()))
       is distinct from v_inv.target_email then
      raise exception 'Bu davet başka bir hesap için üretilmiş';
    end if;
  end if;

  if v_inv.purpose='guardian_link' then
    perform public._c1_require_identity(auth.uid());
    if not exists(select 1 from public.athletes a join public.club_memberships m on m.club_id=a.club_id
     where a.id=v_inv.athlete_id and m.profile_id=v_inv.created_by and m.status='active' and m.role in ('club_admin','coach','official')) then
     raise exception 'Veli davetinin yetkilisi artık geçerli değil';end if;
  elsif v_inv.purpose not in ('accountant','turf_manager') then raise exception 'Davet amacı geçersiz';end if;
  update public.invite_codes set used_at=clock_timestamp(),used_by=auth.uid() where id=v_inv.id;

  if v_inv.purpose = 'accountant' then
    insert into public.club_accountants (club_id, profile_id, added_by, status)
    values (v_inv.club_id, auth.uid(), v_inv.created_by, 'active')
    on conflict (club_id, profile_id)
      do update set status = 'active';

  elsif v_inv.purpose = 'turf_manager' then
    insert into public.turf_field_managers (field_id, profile_id, added_by, status)
    values (v_inv.field_id, auth.uid(), v_inv.created_by, 'active')
    on conflict (field_id, profile_id)
      do update set status = 'active';

  else
    select coalesce(full_name, 'Veli') into v_name
      from public.profiles where id = auth.uid();
    insert into public.guardians
      (athlete_id, profile_id, display_name, relationship, can_contact)
    values (v_inv.athlete_id, auth.uid(), v_name, 'Veli', true);
  end if;


end; $$;
create or replace function public.federation_publish_roster(p_participant uuid,p_athletes uuid[],p_reason text,p_expected_version int)
returns uuid language plpgsql security definer set search_path=public as $$
declare p public.org_participants;o public.organizations;a uuid;v uuid;n int;
begin
 perform public._c1_require_identity(auth.uid());
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
 perform public._c1_require_athlete(x,p.club_id,o.sport_code) from unnest(p_athletes) x;
 insert into public.org_roster_revisions(participant_id,version,athlete_ids,reason,actor_id) values(p.id,n+1,p_athletes,p_reason,auth.uid()) returning id into v;
 insert into public.federation_audit(actor_id,appointment_id,action,entity_id,detail) values(auth.uid(),a,'roster_revision',v,jsonb_build_object('version',n+1));return v;
end $$;

create or replace function public._c1_application_guard()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.kind='offer' then
  perform public._c1_actor_for_club(new.club_id);
  if new.created_by is distinct from auth.uid() or not public.can_review_club_applications(new.club_id) then
   raise exception 'Teklif kulüp yetkilisinden gelmeli';end if;
 else
  if new.profile_id is distinct from auth.uid() then raise exception 'Başvuru sahibi uyuşmuyor';end if;
  perform public._c1_require_member(new.profile_id,new.club_id,new.desired_role,null,
   case when new.desired_role='coach' then public.coach_level_for_sport(new.profile_id,(select sport_code from public.clubs where id=new.club_id)) end);
 end if;
 if new.status<>'pending' or new.desired_role not in ('athlete','coach') then raise exception 'Başvuru rol/durum geçersiz';end if;
 return new;
end $$;
drop trigger if exists c1_application_guard on public.club_applications;
create trigger c1_application_guard before insert on public.club_applications for each row execute function public._c1_application_guard();

-- Old account-linking RPCs also pass through this guard; a profile edit cannot
-- attach a child to an already active new membership without a live guardian.
create or replace function public._c1_athlete_link_guard()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.profile_id is null then return new;end if;
 perform public._c1_actor_for_club(new.club_id);
 if tg_op='UPDATE' and (new.profile_id,new.club_id,new.birth_date) is not distinct from
   (old.profile_id,old.club_id,old.birth_date) then return new;end if;
 if exists(select 1 from public.club_memberships m where m.profile_id=new.profile_id and m.club_id=new.club_id
   and m.status='active' and m.role='athlete' and m.identity_gate_legacy) then return new;end if;
 perform public._c1_require_identity(new.profile_id);
 if exists(select 1 from public.club_memberships m where m.profile_id=new.profile_id and m.club_id=new.club_id
   and m.status='active' and m.role='athlete') then
  if (new.birth_date is null or new.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date) then
   perform public._c1_require_guardian(new.id);end if;
 end if;
 return new;
end $$;
drop trigger if exists c1_athlete_link_guard on public.athletes;
create trigger c1_athlete_link_guard before insert or update on public.athletes for each row execute function public._c1_athlete_link_guard();

-- Private helper/trigger ACLs and historical endpoint ACLs are explicit.
do $$ declare r record;begin
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and left(p.proname,4)='_c1_' loop
  execute format('revoke all on function %s from public,anon,authenticated',r.sig);
 end loop;
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('create_club','apply_to_club','offer_to_person',
  'review_club_application','create_guardian_invite','redeem_invite_code','federation_publish_roster') loop
  execute format('revoke all on function %s from public,anon,authenticated',r.sig);
  execute format('grant execute on function %s to authenticated',r.sig);
 end loop;
end $$;
