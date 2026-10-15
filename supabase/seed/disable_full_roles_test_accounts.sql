-- Yalnız full_roles_test_seed.sql v2 hesaplarını devre dışı bırakır; SİLMEZ.
-- SQL Editor'de yedek aldıktan sonra; otomatik deployment'a eklemeyin.
-- İptal edilen yetkiler seed tekrarında sessizce açılmaz. Auth banı da korunur.
do $disable$
declare
 v_confirmation text := 'CHANGE_ME'; -- 'TEST_HESAPLARINI_KAPAT'
 v_reviewer_id uuid := null; -- Aktif kulüp üyeliği varsa gerçek, kimliği onaylı admin gerekir.
 v_previous_sub text := current_setting('request.jwt.claim.sub',true);
begin
 perform set_config('lock_timeout','15s',true);
 if v_confirmation<>'TEST_HESAPLARINI_KAPAT' then raise exception 'Kapatma onayı gerekli';end if;
 if current_user in ('anon','authenticated','service_role') then raise exception 'SQL Editor yönetici oturumu gerekli';end if;
 perform pg_advisory_xact_lock(hashtext('swansport-live-role-tests-v2'));
 create temporary table _swan_disable_targets(id uuid primary key) on commit drop;
 insert into _swan_disable_targets select id from auth.users
  where raw_app_meta_data->>'seed_owner'='swansport-live-role-tests-v2'
  and email like '%@test.swansport.invalid'
  and id=md5('swansport-live-role-tests-v2/'||split_part(email,'@',1))::uuid;
 if exists(select 1 from public.club_memberships where profile_id in(select id from _swan_disable_targets)
  and status='active') then
  if not exists(select 1 from public.profiles where id=v_reviewer_id and is_platform_admin
   and public._c1_has_identity(id) and id not in(select id from _swan_disable_targets)) then
   raise exception 'Aktif üyelikleri askıya almak için gerçek v_reviewer_id gerekli';
  end if;
  perform set_config('request.jwt.claim.sub',v_reviewer_id::text,true);
  -- 1. kademe güncellemesinde süpervizör hâlâ aktif olmalı: önce yardımcıları askıya al.
  update public.club_memberships set status='suspended'
   where profile_id in(select id from _swan_disable_targets) and status='active'
    and role='coach' and coach_level=1;
  update public.club_memberships set status='suspended'
   where profile_id in(select id from _swan_disable_targets) and status='active';
 end if;
 update public.profiles set is_platform_admin=false where id in(select id from _swan_disable_targets);
 update public.federation_roles set revoked_at=clock_timestamp()
  where profile_id in(select id from _swan_disable_targets) and revoked_at is null;
 update public.federation_appointments set revoked_at=clock_timestamp()
  where profile_id in(select id from _swan_disable_targets) and revoked_at is null;
 update public.referee_profiles set is_active=false where profile_id in(select id from _swan_disable_targets);
 update public.club_accountants set status='revoked' where profile_id in(select id from _swan_disable_targets);
 update public.club_staff_permissions set revoked_at=clock_timestamp(),revoked_by=v_reviewer_id
  where profile_id in(select id from _swan_disable_targets) and revoked_at is null;
 update public.turf_field_managers set status='revoked' where profile_id in(select id from _swan_disable_targets);
 update public.turf_duty_delegations set revoked_at=clock_timestamp()
  where (issuer_id in(select id from _swan_disable_targets) or recipient_id in(select id from _swan_disable_targets))
   and revoked_at is null;
 -- Mağaza üyeliğinde revoked durumu yok: test mağazası askıya alınır, ilişki korunur.
 update public.stores set status='suspended' where id='53570000-0000-4000-8000-000000000003'
  and slug='swansport-role-tests-v2' and exists(select 1 from _swan_disable_targets);
 update auth.users set banned_until='2099-12-31T23:59:59Z',updated_at=clock_timestamp()
  where id in(select id from _swan_disable_targets);
 -- Auth sürümüne göre isteğe bağlı oturum tabloları. JWT'ler yine expiry'ye kadar yaşayabilir.
 if to_regclass('auth.refresh_tokens') is not null then
  execute 'delete from auth.refresh_tokens where user_id::text in(select id::text from _swan_disable_targets)';
 end if;
 if to_regclass('auth.sessions') is not null then
  execute 'delete from auth.sessions where user_id in(select id from _swan_disable_targets)';
 end if;
 perform set_config('request.jwt.claim.sub',coalesce(v_previous_sub,''),true);
end
$disable$;
select count(*) as devre_disi_test_hesabi from auth.users
 where raw_app_meta_data->>'seed_owner'='swansport-live-role-tests-v2'
 and email like '%@test.swansport.invalid'
 and id=md5('swansport-live-role-tests-v2/'||split_part(email,'@',1))::uuid
 and banned_until>clock_timestamp();
