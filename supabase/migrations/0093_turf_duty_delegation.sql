-- Temporary occupancy duty. Permanent manager membership never changes.
set local lock_timeout='15s';
create table if not exists public.turf_duty_delegations(
 id uuid primary key,field_id uuid not null references turf_fields(id) on delete cascade,
 issuer_id uuid not null references profiles(id),recipient_id uuid references profiles(id),
 token uuid not null unique default gen_random_uuid(),hours int not null check(hours between 1 and 168),
 created_at timestamptz not null default clock_timestamp(),valid_until timestamptz not null,invite_until timestamptz not null,
 accepted_at timestamptz,revoked_at timestamptz,revoked_by uuid references profiles(id),
 check(recipient_id is null or recipient_id<>issuer_id),check(valid_until>created_at)
);
create index if not exists turf_duty_recipient on turf_duty_delegations(recipient_id,valid_until) where revoked_at is null;
alter table turf_duty_delegations enable row level security;
drop policy if exists duty_self on turf_duty_delegations;
create policy duty_self on turf_duty_delegations for select to authenticated using(issuer_id=auth.uid() or recipient_id=auth.uid());
revoke insert,update,delete on turf_duty_delegations from public,anon,authenticated;

create or replace function public.can_edit_turf_occupancy(p_field uuid) returns boolean language sql volatile security definer set search_path=public as $$
 select public.is_turf_manager(p_field) or (auth.uid() is not null and public._swan_feature_for_profile('turf_delegation',auth.uid()) and exists(
 select 1 from turf_duty_delegations d join turf_field_managers m on m.field_id=d.field_id and m.profile_id=d.issuer_id and m.status='active'
 join turf_fields f on f.id=d.field_id and f.active
 where d.field_id=p_field and d.recipient_id=auth.uid() and d.accepted_at is not null and d.revoked_at is null and d.valid_until>clock_timestamp()));
$$;
revoke all on function public.can_edit_turf_occupancy(uuid) from public,anon;
grant execute on function public.can_edit_turf_occupancy(uuid) to authenticated;
drop policy if exists turf_occupancy_manage on turf_occupancy;
create policy turf_occupancy_manage on turf_occupancy for all to authenticated using(public.can_edit_turf_occupancy(field_id)) with check(public.can_edit_turf_occupancy(field_id));

create table if not exists public.turf_occupancy_audit(
 id uuid primary key default gen_random_uuid(),field_id uuid not null,starts_at timestamptz not null,
 actor_id uuid,action text not null,changed_at timestamptz not null default clock_timestamp()
);
alter table turf_occupancy_audit enable row level security;
drop policy if exists occupancy_audit_staff on turf_occupancy_audit;
create policy occupancy_audit_staff on turf_occupancy_audit for select to authenticated using(is_turf_manager(field_id) or actor_id=auth.uid());
revoke insert,update,delete on turf_occupancy_audit from public,anon,authenticated;
create or replace function public.guard_delegated_turf_write() returns trigger language plpgsql security definer set search_path=public as $$
declare f uuid;at_time timestamptz;begin
 f:=case when tg_op='DELETE' then old.field_id else new.field_id end;
 at_time:=case when tg_op='DELETE' then old.starts_at else new.starts_at end;
 if not public.is_turf_manager(f) then
  if not public.can_edit_turf_occupancy(f) then raise exception 'Saha görevin bitmiş veya geri alınmış.';end if;
  if at_time<clock_timestamp() or at_time>clock_timestamp()+interval '7 days' or at_time<>date_trunc('hour',at_time)
   or not exists(select 1 from turf_fields t where t.id=f and t.active and (at_time at time zone 'Europe/Istanbul')::time>=t.opens_at and (at_time at time zone 'Europe/Istanbul')::time<t.closes_at) then raise exception 'Geçerli bir gelecek saha saati seç.';end if;
  if tg_op='UPDATE' and (new.id<>old.id or new.field_id<>old.field_id or new.starts_at<>old.starts_at) then raise exception 'Doluluk kaydının yeri değiştirilemez.';end if;
  if tg_op<>'DELETE' and length(coalesce(new.note,''))>500 then raise exception 'Not en fazla 500 karakter olabilir.';end if;
 end if;
 if tg_op='INSERT' then new.created_by:=auth.uid();end if;
 if tg_op='DELETE' then return old;end if;return new;
end;$$;
create or replace function public.audit_turf_write() returns trigger language plpgsql security definer set search_path=public as $$begin
 if tg_op='DELETE' then insert into turf_occupancy_audit(field_id,starts_at,actor_id,action) values(old.field_id,old.starts_at,auth.uid(),tg_op);return old;end if;
 insert into turf_occupancy_audit(field_id,starts_at,actor_id,action) values(new.field_id,new.starts_at,auth.uid(),tg_op);return new;
end;$$;
drop trigger if exists guard_delegated_turf_write on turf_occupancy;
create trigger guard_delegated_turf_write before insert or update or delete on turf_occupancy for each row execute function guard_delegated_turf_write();
drop trigger if exists audit_turf_write on turf_occupancy;
create trigger audit_turf_write after insert or update or delete on turf_occupancy for each row execute function audit_turf_write();
revoke all on function public.guard_delegated_turf_write(),public.audit_turf_write() from public,anon,authenticated;

create or replace function public.create_turf_duty(p_field uuid,p_hours int,p_op uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare d turf_duty_delegations;begin
 if auth.uid() is null or not public.is_turf_manager(p_field) or not public._swan_feature_for_profile('turf_delegation',auth.uid()) then raise exception 'Görev devri yalnız sahanın mevcut yöneticisine açık.';end if;
 -- Manager row first: concurrent revocation cannot mint a grant from stale authority.
 perform 1 from turf_field_managers where field_id=p_field and profile_id=auth.uid() and status='active' for update;
 if not found then raise exception 'Yönetici yetkin kaldırılmış.';end if;
 if p_op is null or p_hours is null or p_hours<1 or p_hours>168 or not exists(select 1 from turf_fields where id=p_field and active) then raise exception 'Geçerli saha ve 1–168 saat seç.';end if;
 select * into d from turf_duty_delegations where id=p_op;
 if d.id is not null then
  if d.issuer_id<>auth.uid() or d.field_id<>p_field or d.hours<>p_hours then raise exception 'İşlem kimliği farklı veriyle kullanılamaz.';end if;
  return jsonb_build_object('code',d.token,'valid_until',d.valid_until,'invite_until',d.invite_until);
 end if;
 if (select count(*) from turf_duty_delegations where issuer_id=auth.uid() and revoked_at is null and valid_until>clock_timestamp() and recipient_id is null and invite_until>clock_timestamp())>=5 then raise exception 'Önce bekleyen davetlerinden birini geri al.';end if;
 insert into turf_duty_delegations(id,field_id,issuer_id,hours,valid_until,invite_until)
 values(p_op,p_field,auth.uid(),p_hours,clock_timestamp()+make_interval(hours=>p_hours),least(clock_timestamp()+interval '24 hours',clock_timestamp()+make_interval(hours=>p_hours))) returning * into d;
 return jsonb_build_object('code',d.token,'valid_until',d.valid_until,'invite_until',d.invite_until);
end;$$;
create or replace function public.redeem_turf_duty(p_code text) returns uuid language plpgsql security definer set search_path=public as $$
declare d turf_duty_delegations;begin
 if auth.uid() is null or not public._swan_feature_for_profile('turf_delegation',auth.uid()) then raise exception 'Saha görevi erişimi kapalı.';end if;
 if p_code is null or lower(trim(p_code)) !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then raise exception 'Davet geçersiz veya süresi dolmuş.';end if;
 select * into d from turf_duty_delegations where token=lower(trim(p_code))::uuid;
 if d.id is null then raise exception 'Davet geçersiz veya süresi dolmuş.';end if;
 -- Same lock order as creation/revocation.
 perform 1 from turf_field_managers where field_id=d.field_id and profile_id=d.issuer_id and status='active' for update;
 if not found then raise exception 'Davet geçersiz veya süresi dolmuş.';end if;
 select * into d from turf_duty_delegations where id=d.id for update;
 if d.revoked_at is not null or d.valid_until<=clock_timestamp() or not exists(select 1 from turf_fields where id=d.field_id and active) then raise exception 'Davet geçersiz veya süresi dolmuş.';end if;
 if d.recipient_id=auth.uid() then return d.id;end if;
 if d.recipient_id is not null or d.invite_until<=clock_timestamp() or d.issuer_id=auth.uid() then raise exception 'Davet geçersiz veya süresi dolmuş.';end if;
 update turf_duty_delegations set recipient_id=auth.uid(),accepted_at=clock_timestamp() where id=d.id;
 insert into notifications(profile_id,kind,title,body,actor_id,entity_type,entity_id) values
 (d.issuer_id,'turf_delegation','Saha görevi kabul edildi','Geçici görev Saha İşlemlerim ekranından izlenebilir veya geri alınabilir.',auth.uid(),'turf_field',d.field_id),
 (auth.uid(),'turf_delegation','Saha görevin başladı','Yalnız doluluk işaretleyebilirsin. Görev bitişi sunucuda korunur.',d.issuer_id,'turf_field',d.field_id);
 return d.id;
end;$$;
create or replace function public.revoke_turf_duty(p_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare d turf_duty_delegations;begin
 select * into d from turf_duty_delegations where id=p_id;
 if auth.uid() is null or d.id is null or (d.issuer_id<>auth.uid() and d.recipient_id is distinct from auth.uid()) then raise exception 'Bu göreve erişilemiyor.';end if;
 perform 1 from turf_field_managers where field_id=d.field_id and profile_id=d.issuer_id for update;
 select * into d from turf_duty_delegations where id=p_id for update;
 if d.revoked_at is not null then return;end if;
 update turf_duty_delegations set revoked_at=clock_timestamp(),revoked_by=auth.uid() where id=p_id;
 if d.recipient_id is not null then insert into notifications(profile_id,kind,title,body,entity_type,entity_id)
 values(case when auth.uid()=d.issuer_id then d.recipient_id else d.issuer_id end,'turf_delegation','Saha görevi sona erdi','Geçici doluluk görevi geri alındı.','turf_field',d.field_id);end if;
end;$$;
create or replace function public.my_turf_duties(p_offset int default 0) returns jsonb language plpgsql security definer set search_path=public as $$declare result jsonb;begin
 if auth.uid() is null or not public._swan_feature_for_profile('turf_delegation',auth.uid()) then raise exception 'Saha görevi erişimi kapalı.';end if;
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Geçersiz sayfa.';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'field_id',d.field_id,'field_name',t.name,'venue_name',t.venue_name,'issuer',d.issuer_id=auth.uid(),
 'valid_until',d.valid_until,'invite_until',d.invite_until,'status',case when d.revoked_at is not null then 'revoked' when d.valid_until<=clock_timestamp() or not t.active or not exists(select 1 from turf_field_managers m where m.field_id=d.field_id and m.profile_id=d.issuer_id and m.status='active') then 'expired' when d.recipient_id is not null then 'active' when d.invite_until<=clock_timestamp() then 'expired' else 'invited' end)
 order by d.created_at desc,d.id desc),'[]'::jsonb) into result from (select * from turf_duty_delegations where issuer_id=auth.uid() or recipient_id=auth.uid() order by created_at desc,id desc offset p_offset limit 41) d join turf_fields t on t.id=d.field_id;
 return jsonb_build_object('items',result-40,'has_more',jsonb_array_length(result)>40);
end;$$;
create or replace function public.my_delegated_turf_fields() returns jsonb language plpgsql stable security definer set search_path=public as $$begin
 if auth.uid() is null then return '[]'::jsonb;end if;
 return coalesce((select jsonb_agg(distinct d.field_id) from turf_duty_delegations d where d.recipient_id=auth.uid() and public.can_edit_turf_occupancy(d.field_id)),'[]'::jsonb);
end;$$;
revoke all on function public.create_turf_duty(uuid,int,uuid),public.redeem_turf_duty(text),public.revoke_turf_duty(uuid),public.my_turf_duties(int),public.my_delegated_turf_fields() from public,anon;
grant execute on function public.create_turf_duty(uuid,int,uuid),public.redeem_turf_duty(text),public.revoke_turf_duty(uuid),public.my_turf_duties(int),public.my_delegated_turf_fields() to authenticated;
insert into public.feature_flags(key,audience,label,description) values('turf_delegation','admins','Süreli saha doluluk görevi','Kalıcı yönetici değiştirmeden davetle süreli doluluk düzenleme.') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Halı saha doluluk görevini geçici devredebilir miyim?','Sahanın mevcut yöneticisiysen detay ekranındaki Görev devret düğmesini kullan. 1–168 saat seçip oluşturulan özel davet kodunu görev alacak kişiye ilet. Kod en fazla 24 saat içinde kabul edilir; görev süresi kod oluşturulduğunda başlar, kabul etmek uzatmaz. Diğer kişi Profil > Yönetim > Saha İşlemlerim ekranında kodu kabul eder ve aktif görevin Sahayı aç düğmesiyle doluluk panosuna geçer. Yalnız doluluk işlemleri açılır; yönetici atama veya tekrar devir hakkı verilmez. Senin kalıcı yöneticiliğin sona ererse ya da görevi geri alırsan erişim hemen kesilir.','Sahalar','everyone',198,'/saha-islemlerim','turf_delegation'
where not exists(select 1 from faq_entries where feature='turf_delegation' and active);
