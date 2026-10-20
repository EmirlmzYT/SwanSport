set local lock_timeout = '15s';
create table if not exists public.transfer_requests (
 id uuid primary key,athlete_id uuid not null references public.athletes(id) on delete cascade,
 sport_code text not null references public.sports(code),
 from_club_id uuid not null references public.clubs(id) on delete cascade,to_club_id uuid not null references public.clubs(id) on delete cascade,
 created_by uuid references public.profiles(id) on delete set null,reason text not null check(length(trim(reason)) between 1 and 500),
 status text not null default 'pending' check(status in ('pending','completed','rejected','cancelled')),
 consent_by uuid references public.profiles(id) on delete set null,consented_at timestamptz,
 accepted_by uuid references public.profiles(id) on delete set null,accepted_at timestamptz,
 decided_by uuid references public.profiles(id) on delete set null,decided_at timestamptz,
 transfer_id uuid references public.athlete_transfers(id),
 created_at timestamptz not null default clock_timestamp(),check(from_club_id<>to_club_id)
);
create unique index if not exists one_pending_transfer_per_sport on public.transfer_requests(athlete_id,sport_code) where status='pending';
alter table public.transfer_requests enable row level security;
revoke all on public.transfer_requests from public,anon,authenticated;
create table if not exists public.transfer_request_events (
 id bigint generated always as identity primary key,request_id uuid not null references public.transfer_requests(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,action text not null,recorded_at timestamptz not null default clock_timestamp()
);
alter table public.transfer_request_events enable row level security;
revoke all on public.transfer_request_events from public,anon,authenticated;
create or replace function public._audit_transfer_request()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$begin
 insert into transfer_request_events(request_id,actor_id,action) values(new.id,auth.uid(),
 case when tg_op='INSERT' then 'submitted' when new.status<>old.status then new.status
 when new.consent_by is distinct from old.consent_by then 'consented' else 'accepted' end);
 return new;
end $$;
revoke all on function public._audit_transfer_request() from public,anon,authenticated;
drop trigger if exists audit_transfer_request on public.transfer_requests;
create trigger audit_transfer_request after insert or update on public.transfer_requests for each row execute function public._audit_transfer_request();

create or replace function public._transfer_consent_actor(p_athlete uuid,p_actor uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select p_actor is not null and exists(select 1 from athletes a where a.id=p_athlete and
 case when a.birth_date is not null and a.birth_date<=((clock_timestamp() at time zone 'Europe/Istanbul')::date-interval '18 years')::date
 then a.profile_id=p_actor
 else exists(select 1 from guardians g where g.athlete_id=a.id and g.profile_id=p_actor) end)
$$;
create or replace function public._transfer_admin(p_club uuid,p_actor uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from club_memberships m where m.club_id=p_club and m.profile_id=p_actor and m.role='club_admin' and m.status='active')
$$;
create or replace function public._transfer_registrar(p_sport text,p_from uuid,p_to uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select auth.uid() is not null and not exists(select 1 from clubs c where c.id in(p_from,p_to) and not exists(
  select 1 from federation_appointments a join federation_offices o on o.id=a.office_id join federations f on f.id=o.federation_id
  where a.profile_id=auth.uid() and a.duty='license_registrar' and a.revoked_at is null and f.sport_code=p_sport
  and a.starts_on<=(clock_timestamp() at time zone 'Europe/Istanbul')::date and a.ends_on>=(clock_timestamp() at time zone 'Europe/Istanbul')::date
  and (o.city_code is null or o.city_code=c.registration_city_code)))
$$;
create or replace function public._transfer_require_enabled()
returns void language plpgsql security definer set search_path=public,pg_temp as $$begin
 if auth.uid() is null or not exists(select 1 from my_feature_flags() f where f.key='transfer_requests') then
  raise exception 'Transfer talepleri hesabına açık değil.' using errcode='42501';end if;
end $$;
revoke all on function public._transfer_consent_actor(uuid,uuid),public._transfer_admin(uuid,uuid),public._transfer_registrar(text,uuid,uuid),public._transfer_require_enabled() from public,anon,authenticated;

create or replace function public.transfer_request_options()
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$begin
 perform _transfer_require_enabled();
 return jsonb_build_object('athletes',coalesce((select jsonb_agg(to_jsonb(q)) from (
  select a.id,case when a.club_id=r.club_id then concat_ws(' ',a.first_name,a.last_name) else athlete_ref(a.id) end name,r.sport_code,r.club_id from_club_id,c.name club_name
  from athlete_sport_registrations r join athletes a on a.id=r.athlete_id and a.status='active'
  join clubs c on c.id=r.club_id and c.status='active'
  where _transfer_admin(r.club_id,auth.uid()) order by a.last_name,a.first_name,r.sport_code
 )q),'[]'::jsonb),'clubs',coalesce((select jsonb_agg(to_jsonb(q)) from (
  select c.id,c.name,r.sport_code from club_sport_registrations r join clubs c on c.id=r.club_id and c.status='active'
  where exists(select 1 from athlete_sport_registrations ar where ar.sport_code=r.sport_code and _transfer_admin(ar.club_id,auth.uid()))
  order by c.name,c.id,r.sport_code
 )q),'[]'::jsonb));
end $$;

create or replace function public.submit_transfer_request(p_id uuid,p_athlete uuid,p_sport text,p_to uuid,p_reason text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare r athlete_sport_registrations;old transfer_requests;
begin
 perform _transfer_require_enabled();
 -- Same lock as the existing official transfer engine, before request row locks.
 perform pg_advisory_xact_lock(940096);
 select * into old from transfer_requests where id=p_id;
 if found then
  if (old.athlete_id,old.sport_code,old.to_club_id,old.reason,old.created_by) is distinct from
   (p_athlete,p_sport,p_to,trim(p_reason),auth.uid()) then raise exception 'İşlem kimliği farklı talebe ait' using errcode='22023';end if;
  if not _transfer_admin(old.from_club_id,auth.uid()) then raise exception 'Aktif kaynak kulüp yöneticisi gerekli' using errcode='42501';end if;
  return old.id;
 end if;
 select * into r from athlete_sport_registrations where athlete_id=p_athlete and sport_code=p_sport for share;
 if not coalesce(_transfer_admin(r.club_id,auth.uid()),false) then raise exception 'Aktif kaynak kulüp yöneticisi gerekli' using errcode='42501';end if;
 perform 1 from athletes where id=p_athlete and status='active' for share;
 if not found or p_id is null or p_reason is null or length(trim(p_reason)) not between 1 and 500 or p_to is null or p_to=r.club_id or
 not exists(select 1 from clubs where id=r.club_id and status='active') or
 not exists(select 1 from clubs where id=p_to and status='active') or
 not exists(select 1 from club_sport_registrations where club_id=p_to and sport_code=p_sport) then
  raise exception 'Aktif sporcu, farklı tescilli hedef kulüp ve 1–500 karakter gerekçe gerekli' using errcode='22023';end if;
 insert into transfer_requests(id,athlete_id,sport_code,from_club_id,to_club_id,created_by,reason)
 values(p_id,p_athlete,p_sport,r.club_id,p_to,auth.uid(),trim(p_reason));return p_id;
end $$;

create or replace function public.my_transfer_requests()
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$begin
 perform _transfer_require_enabled();
 return coalesce((select jsonb_agg(to_jsonb(q)) from (
 select r.id,athlete_ref(r.athlete_id) athlete_reference,
 case when _transfer_consent_actor(r.athlete_id,auth.uid()) then (select concat_ws(' ',a.first_name,a.last_name) from athletes a where a.id=r.athlete_id) end family_name,
 r.sport_code,f.name from_club,t.name to_club,r.reason,r.status,r.created_at,
 r.consented_at is not null and _transfer_consent_actor(r.athlete_id,r.consent_by) consented,
 r.accepted_at is not null and _transfer_admin(r.to_club_id,r.accepted_by) accepted,r.transfer_id,
 r.status='pending' and _transfer_admin(r.to_club_id,auth.uid()) can_accept,
 r.status='pending' and _transfer_consent_actor(r.athlete_id,auth.uid()) can_consent,
 r.status='pending' and _transfer_registrar(r.sport_code,r.from_club_id,r.to_club_id) can_finalize,
 r.status='pending' and _transfer_admin(r.from_club_id,auth.uid()) can_cancel,
 r.status='pending' can_reject
 from transfer_requests r join clubs f on f.id=r.from_club_id join clubs t on t.id=r.to_club_id
 where _transfer_admin(r.from_club_id,auth.uid()) or _transfer_admin(r.to_club_id,auth.uid()) or
 _transfer_consent_actor(r.athlete_id,auth.uid()) or _transfer_registrar(r.sport_code,r.from_club_id,r.to_club_id)
 order by r.created_at desc,r.id limit 100
 )q),'[]'::jsonb);
end $$;

create or replace function public.act_transfer_request(p_id uuid,p_action text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r transfer_requests;official boolean;v uuid;current_club uuid;
begin
 perform _transfer_require_enabled();perform pg_advisory_xact_lock(940096);
 select * into r from transfer_requests where id=p_id for update;
 if r.id is null then raise exception 'Talebe erişilemiyor' using errcode='42501';end if;
 official:=_transfer_registrar(r.sport_code,r.from_club_id,r.to_club_id);
 if not (_transfer_admin(r.from_club_id,auth.uid()) or _transfer_admin(r.to_club_id,auth.uid()) or
 _transfer_consent_actor(r.athlete_id,auth.uid()) or official) then raise exception 'Talebe erişilemiyor' using errcode='42501';end if;
 -- Explicit set actions are retry-safe; terminal states never reopen.
 if (p_action='finalize' and r.status='completed' and r.decided_by=auth.uid()) or
 (p_action='reject' and r.status='rejected' and r.decided_by=auth.uid()) or
 (p_action='cancel' and r.status='cancelled' and r.decided_by=auth.uid()) then return;end if;
 if r.status<>'pending' then raise exception 'Talep kapanmış' using errcode='55000';end if;
 case p_action
 when 'accept' then
  if not _transfer_admin(r.to_club_id,auth.uid()) then raise exception 'Hedef kulüp yöneticisi gerekli' using errcode='42501';end if;
  if r.accepted_by is distinct from auth.uid() then update transfer_requests set accepted_by=auth.uid(),accepted_at=clock_timestamp() where id=r.id;end if;
 when 'consent' then
  if not _transfer_consent_actor(r.athlete_id,auth.uid()) then raise exception 'Reşit sporcu veya gerçek veli gerekli' using errcode='42501';end if;
  if r.consent_by is distinct from auth.uid() then update transfer_requests set consent_by=auth.uid(),consented_at=clock_timestamp() where id=r.id;end if;
 when 'cancel' then
  if not _transfer_admin(r.from_club_id,auth.uid()) then raise exception 'Kaynak kulüp yöneticisi gerekli' using errcode='42501';end if;
  update transfer_requests set status='cancelled',decided_by=auth.uid(),decided_at=clock_timestamp() where id=r.id;
 when 'reject' then
  update transfer_requests set status='rejected',decided_by=auth.uid(),decided_at=clock_timestamp() where id=r.id;
 when 'finalize' then
  if not official then raise exception 'Aktif branş/il lisans tescil yetkisi gerekli' using errcode='42501';end if;
  -- Recheck consent and memberships under row locks before the official engine.
  perform 1 from club_memberships where club_id in(r.from_club_id,r.to_club_id) and profile_id in(r.created_by,r.accepted_by) order by id for share;
  perform 1 from athletes where id=r.athlete_id for share;
  perform 1 from guardians where athlete_id=r.athlete_id for share;
  if not _transfer_admin(r.from_club_id,r.created_by) or not _transfer_admin(r.to_club_id,r.accepted_by) or
   not coalesce(_transfer_consent_actor(r.athlete_id,r.consent_by),false) then raise exception 'Kaynak/hedef yetkisi ve sporcu/veli onayı tamamlanmalı' using errcode='22023';end if;
  select club_id into current_club from athlete_sport_registrations where athlete_id=r.athlete_id and sport_code=r.sport_code for update;
  if current_club is distinct from r.from_club_id then raise exception 'Resmî kulüp kaydı değişti; talebi iptal edip yeniden hazırla' using errcode='22023';end if;
  perform _federation_require(r.sport_code,(select registration_city_code from clubs where id=r.from_club_id),'license_registrar');
  perform _federation_require(r.sport_code,(select registration_city_code from clubs where id=r.to_club_id),'license_registrar');
  v:=federation_transfer_athlete(r.athlete_id,r.sport_code,r.to_club_id,r.reason);
  update transfer_requests set status='completed',transfer_id=v,decided_by=auth.uid(),decided_at=clock_timestamp() where id=r.id;
 else raise exception 'Geçersiz talep işlemi' using errcode='22023';end case;
end $$;
revoke all on function public.transfer_request_options(),public.submit_transfer_request(uuid,uuid,text,uuid,text),public.my_transfer_requests(),public.act_transfer_request(uuid,text) from public,anon;
grant execute on function public.transfer_request_options(),public.submit_transfer_request(uuid,uuid,text,uuid,text),public.my_transfer_requests(),public.act_transfer_request(uuid,text) to authenticated;

insert into public.feature_flags(key,audience,label,description) values
 ('transfer_requests','admins','Transfer talepleri','Kaynak/hedef kulüp, sporcu/veli ve yetkili federasyon tescil akışı.') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Resmî transfer talebi nasıl ilerler?',
 'Profil > Yönetim > Transfer Talepleri ekranında kaynak kulüp yöneticisi kayıtlı sporcu, branş ve tescilli hedef kulübü seçerek talep açar. Hedef kulüp kabul eder; reşit sporcu veya çocuk/bilinmeyen yaş için gerçek bağlı veli ayrıca onay verir. Taraflar reddedebilir; kaynak kulüp iptal edebilir. Son tescili yalnız iki ilin ilgili branşında lisans tescil yetkisi bulunan federasyon görevlisi yapar. Kulüp kabulü resmî transfer değildir. Tamamlanana kadar lisans ve kadro değişmez. Tamamlama mevcut resmî transfer motorunu kullanır; eski resmî sonuç/esame görüntüleri korunur. Son 100 talep gösterilir.',
 'Kulüp','everyone',214,'/transfer-talepleri','transfer_requests'
where not exists(select 1 from public.faq_entries where feature='transfer_requests' and active);
