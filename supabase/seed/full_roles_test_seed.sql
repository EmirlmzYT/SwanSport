-- CANLI rol testi; migration/otomatik seed DEĞİLDİR. Önce rehberi okuyup yedek alın.
-- 45 ayrılmış hesap, YENİ hesap şifresi: test1234. Eski şifre/ban değiştirilmez.
-- Gerçek kimlik onayı, TCKN, telefon, lisans, aidat, maç sonucu UYDURULMAZ.
-- Auth şeması sürüme bağlıdır; SQL testi gerçek GoTrue giriş kanıtı değildir.
-- Kurulum TEK statement'tır: ayrı SQL Editor oturumlarında temp tablo kaybolmaz.
do $seed$
declare
 -- ELLE değiştir: 'CANLI_TEST_HESAPLARINI_ONAYLIYORUM'
 v_confirmation text := 'CHANGE_ME';
 v_enable_platform_admin boolean := false;
 v_enable_federation_roles boolean := false;
 v_federation_id uuid := null;
 v_reviewer_id uuid := null;
 v_sport text := 'futbol';
 v_city text := '34';
 v_marker constant text := 'swansport-live-role-tests-v2';
 v_club constant uuid := '53570000-0000-4000-8000-000000000001';
 v_field constant uuid := '53570000-0000-4000-8000-000000000002';
 v_store constant uuid := '53570000-0000-4000-8000-000000000003';
 v_office uuid;
 v_previous_sub text := current_setting('request.jwt.claim.sub',true);
 v_crypto_schema text;
 v_hash text;
 v_existing auth.users%rowtype;
 v_row record;
 v_relation text;
 v_member_role text;
 v_supervisor uuid;
 v_activated boolean;
begin
 perform set_config('lock_timeout','15s',true);
 if v_confirmation <> 'CANLI_TEST_HESAPLARINI_ONAYLIYORUM' then
  raise exception 'Canlı test güvenlik kilidi: rehberi okuyup v_confirmation değerini değiştirin';
 end if;
 if current_user in ('anon','authenticated','service_role') then
  raise exception 'Yalnız veritabanı yöneticisinin SQL Editor oturumunda çalıştırın';
 end if;
 perform pg_advisory_xact_lock(hashtext(v_marker));

create temporary table _swan_role_accounts (
 slug text primary key, title text not null, category text not null,
 role_key text, coach_level int, profile_id uuid unique, email text unique,
 result text not null default 'Hesap hazır; ek kurulum gerekli'
) on commit drop;
insert into _swan_role_accounts(slug,title,category,role_key,coach_level) values
 ('platform-admin','Platform Yöneticisi','platform','platform_admin',null),
 ('kulup-yoneticisi','Kulüp Yöneticisi','club','club_admin',null),
 ('kulup-gorevlisi','Kulüp Görevlisi','club','official',null),
 ('federasyon-temsilcisi','Eski Federasyon Temsilcisi','club','federation_rep',null),
 ('antrenor-1','1. Kademe Antrenör','club','coach',1),
 ('antrenor-2','2. Kademe Antrenör','club','coach',2),
 ('antrenor-3','3. Kademe Antrenör','club','coach',3),
 ('antrenor-4','4. Kademe Antrenör','club','coach',4),
 ('antrenor-5','5. Kademe Antrenör','club','coach',5),
 ('lisansli-sporcu','Lisanslı Sporcu','club','athlete',null),
 ('ferdi-sporcu','Ferdi Sporcu','individual','athlete_individual',null),
 ('veli','Veli','parent','parent',null),
 ('kulup-baskani','Kulüp Başkanı','staff','president',null),
 ('sportif-direktor','Sportif Direktör','staff','sporting_director',null),
 ('doktor','Doktor','staff','doctor',null),
 ('fizyoterapist','Fizyoterapist','staff','physiotherapist',null),
 ('malzeme-sorumlusu','Malzeme Sorumlusu','staff','kit_manager',null),
 ('medya-sorumlusu','Medya Sorumlusu','staff','media_officer',null),
 ('federasyon-baskani','Federasyon Başkanı','federation','president',null),
 ('yonetim-kurulu','Federasyon Yönetim Kurulu','federation','board_member',null),
 ('genel-sekreter','Genel Sekreter','federation','general_secretary',null),
 ('il-temsilcisi','İl Temsilcisi','federation','provincial_rep',null),
 ('mhk','MHK Üyesi','federation','referee_committee',null),
 ('disiplin-kurulu','Disiplin Kurulu Üyesi','federation','disciplinary_board',null),
 ('sonuc-yayimlayici','Sonuç Yayımlayıcı','appointment','result_publisher',null),
 ('program-yayimlayici','Program Yayımlayıcı','appointment','program_publisher',null),
 ('lisans-tescil','Lisans Tescil Görevlisi','appointment','license_registrar',null),
 ('kulup-tescil','Kulüp Tescil Görevlisi','appointment','club_registrar',null),
 ('bashakem','Başhakem','referee','head_referee',null),
 ('yardimci-hakem-1','1. Yardımcı Hakem','referee','assistant_referee_1',null),
 ('yardimci-hakem-2','2. Yardımcı Hakem','referee','assistant_referee_2',null),
 ('dorduncu-hakem','Dördüncü Hakem','referee','fourth_referee',null),
 ('masa-hakemi','Masa Hakemi','referee','table_official',null),
 ('gozlemci','Gözlemci','referee','observer',null),
 ('aday-hakem','Aday Hakem','referee_tier','candidate',null),
 ('il-hakemi','İl Hakemi','referee_tier','provincial',null),
 ('uluslararasi-hakem','Uluslararası Hakem','referee_tier','international',null),
 ('muhasebeci','Muhasebeci','accountant',null,null),
 ('saha-yoneticisi','Halı Saha Yöneticisi','turf','manager',null),
 ('saha-nobetcisi','Geçici Saha Nöbetçisi','turf','delegate',null),
 ('magaza-sahibi','Mağaza Sahibi','store','owner',null),
 ('magaza-yoneticisi','Mağaza Yöneticisi','store','manager',null),
 ('topluluk-uyesi','Topluluk Üyesi','community','member',null),
 ('topluluk-gorevlisi','Topluluk Görevlisi','community','staff',null),
 ('taraftar','Taraftar / Standart Hesap','viewer',null,null);
update _swan_role_accounts set
 profile_id=md5('swansport-live-role-tests-v2/'||slug)::uuid,
 email=slug||'@test.swansport.invalid';

 foreach v_relation in array array['auth.identities','public.club_staff_roles',
  'public.federation_roles','public.referee_profiles','public.federation_appointments',
  'public.club_staff_permissions','public.store_memberships','public.turf_field_managers'] loop
  if to_regclass(v_relation) is null then
   raise exception 'Önkoşul eksik: %. Migration sırasını kontrol edin; seed migration kurmaz',v_relation;
  end if;
 end loop;
 if to_regprocedure('public._c1_has_identity(uuid)') is null then
  raise exception '0100 kimlik kapısı eksik; eski şemada çalıştırılamaz';
 end if;
 if not exists(select 1 from public.sports where code=v_sport)
  or not exists(select 1 from public.cities where code=v_city) then
  raise exception 'Seçilen branş/il referansı eksik';
 end if;
 if not exists(select 1 from information_schema.columns where table_schema='auth'
  and table_name='identities' and column_name='provider_id') then
  raise exception 'GoTrue auth.identities.provider_id eksik; Auth sürümü için uyarlama gerekli';
 end if;
 select n.nspname into v_crypto_schema from pg_extension e
  join pg_namespace n on n.oid=e.extnamespace where e.extname='pgcrypto';
 if v_crypto_schema is null then raise exception 'pgcrypto eksik; seed extension kurmaz';end if;
 if v_reviewer_id is not null and not exists(select 1 from public.profiles p
  where p.id=v_reviewer_id and p.is_platform_admin and public._c1_has_identity(p.id)
  and not exists(select 1 from _swan_role_accounts s where s.profile_id=p.id)) then
  raise exception 'v_reviewer_id gerçek, kimliği doğrulanmış mevcut platform admin olmalı';
 end if;
 if v_enable_federation_roles and not exists(select 1 from public.federations
  where id=v_federation_id and sport_code=v_sport) then
  raise exception 'Hassas federasyon yetkileri için doğru branşta v_federation_id gerekli';
 end if;

 -- E-posta tek başına sahiplik değildir. Bütün çakışmalar ilk yazıdan önce kontrol edilir.
 for v_row in select * from _swan_role_accounts loop
  for v_existing in select * from auth.users where id=v_row.profile_id
   or lower(email)=v_row.email loop
   if v_existing.id<>v_row.profile_id or lower(v_existing.email) is distinct from v_row.email
    or v_existing.raw_app_meta_data->>'seed_owner' is distinct from v_marker then
    raise exception 'Test hesabı çakışması: %. Mevcut hesap değiştirilmedi',v_row.email;
   end if;
  end loop;
  if exists(select 1 from auth.identities i where i.provider='email'
   and (i.provider_id=v_row.profile_id::text or lower(i.identity_data->>'email')=v_row.email
    or i.user_id=v_row.profile_id)
   and (i.user_id<>v_row.profile_id or i.provider_id is distinct from v_row.profile_id::text
    or lower(i.identity_data->>'email') is distinct from v_row.email)) then
   raise exception 'Auth identity başka hesaba bağlı: %',v_row.email;
  end if;
 end loop;
 if exists(select 1 from public.clubs where (id=v_club and
  (name<>'[TEST] SwanSport Rol Test Kulübü' or sport_code is distinct from v_sport or created_by is distinct from
   md5(v_marker||'/kulup-yoneticisi')::uuid)) or
  (id<>v_club and name='[TEST] SwanSport Rol Test Kulübü')) then
  raise exception 'Test kulübü UUID/ad sahipliği çakışması';
 end if;
 if exists(select 1 from public.turf_fields where id=v_field and
  (name<>'[TEST] Rol Test Sahası' or sport_code is distinct from v_sport or city_code is distinct from v_city))
  or exists(select 1 from public.stores where (id=v_store and slug is distinct from
   'swansport-role-tests-v2') or (id<>v_store and slug='swansport-role-tests-v2')) then
  raise exception 'Test saha/mağaza UUID sahipliği çakışması';
 end if;

 for v_row in select * from _swan_role_accounts order by slug loop
  if not exists(select 1 from auth.users where id=v_row.profile_id) then
   -- Aynı parola olsa da her yeni hesap için bağımsız bcrypt salt.
   execute format('select %I.crypt($1,%I.gen_salt(''bf'',10))',v_crypto_schema,v_crypto_schema)
    into v_hash using 'test1234';
   insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    confirmation_token,recovery_token,email_change_token_new,email_change,
    email_change_token_current,phone_change,phone_change_token,reauthentication_token,
    raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
   values('00000000-0000-0000-0000-000000000000',v_row.profile_id,'authenticated','authenticated',
    v_row.email,v_hash,clock_timestamp(),'','','','','','','','',
    jsonb_build_object('provider','email','providers',jsonb_build_array('email'),'seed_owner',v_marker),
    jsonb_build_object('full_name','[TEST] '||v_row.title),clock_timestamp(),clock_timestamp());
  end if;
  insert into public.profiles(id,full_name) values(v_row.profile_id,'[TEST] '||v_row.title)
   on conflict(id) do nothing;
  insert into auth.identities(id,user_id,provider_id,identity_data,provider,created_at,updated_at)
   select gen_random_uuid(),v_row.profile_id,v_row.profile_id::text,
    jsonb_build_object('sub',v_row.profile_id::text,'email',v_row.email,'email_verified',true),
    'email',clock_timestamp(),clock_timestamp()
   where not exists(select 1 from auth.identities where user_id=v_row.profile_id and provider='email');
 end loop;

 if v_enable_platform_admin then
  update public.profiles set is_platform_admin=true where id=md5(v_marker||'/platform-admin')::uuid;
  update _swan_role_accounts set result='AKTİF: global platform admin; test sonrası derhal kaldır'
   where category='platform';
 else
  update _swan_role_accounts set result='ATLANDI: admin seçeneği kapalı; mevcut yetki değişmez'
   where category='platform';
 end if;
 -- Gerçek kulüpler adla bulunmaz. Genel dizine active olarak çıkmaz.
 insert into public.clubs(id,name,short_name,city,sport_code,status,created_by)
 values(v_club,'[TEST] SwanSport Rol Test Kulübü','TEST','İstanbul',v_sport,'pending',
  md5(v_marker||'/kulup-yoneticisi')::uuid) on conflict(id) do nothing;
 insert into public.turf_fields(id,name,venue_name,city_code,sport_code,active)
 values(v_field,'[TEST] Rol Test Sahası','[TEST] SwanSport',v_city,v_sport,false)
 on conflict(id) do nothing;
 insert into public.stores(id,name,slug,city_code,status)
 values(v_store,'[TEST] Rol Test Mağazası','swansport-role-tests-v2',v_city,'pending')
 on conflict(id) do nothing;

 if v_reviewer_id is not null then
  perform set_config('request.jwt.claim.sub',v_reviewer_id::text,true);
 end if;
 -- 1. kademe için önce aktif 5. kademe süpervizör gerekir.
 for v_row in select * from _swan_role_accounts where category in ('club','staff')
  order by coach_level desc nulls last,slug loop
  v_member_role:=case when v_row.category='staff' then
   case when v_row.role_key='president' then 'club_admin' else 'official' end
   else v_row.role_key end;
  v_supervisor:=case when v_row.coach_level=1 then md5(v_marker||'/antrenor-5')::uuid end;
  v_activated:=false;
  -- Sahte kimlik, legacy hakkı veya approved belge üretilmez; trigger/RLS kapatılmaz.
  if v_reviewer_id is null or not public._c1_has_identity(v_row.profile_id) then
   update _swan_role_accounts set result='BEKLİYOR: gerçek kimlik/belge onayı + v_reviewer_id gerekli'
    where slug=v_row.slug;
  else
   begin
    perform public._c1_require_member(v_row.profile_id,v_club,v_member_role,null,v_row.coach_level);
    if not exists(select 1 from public.club_memberships where club_id=v_club
     and profile_id=v_row.profile_id and role::text=v_member_role and team_id is null) then
     insert into public.club_memberships(club_id,profile_id,role,status,coach_level,supervisor_id)
     values(v_club,v_row.profile_id,v_member_role::public.club_role,'active',v_row.coach_level,v_supervisor);
    end if;
    v_activated:=exists(select 1 from public.club_memberships where club_id=v_club
     and profile_id=v_row.profile_id and role::text=v_member_role and status='active' and team_id is null);
    update _swan_role_accounts set result=case when v_activated then 'AKTİF: test kulübü üyeliği'
     else 'BEKLİYOR: mevcut üyelik aktif değil; otomatik yeniden açılmaz' end where slug=v_row.slug;
   exception when sqlstate '42501' or raise_exception then
    update _swan_role_accounts set result='BEKLİYOR: kimlik/branş/kademe/süpervizör koşulları sağlanmadı'
     where slug=v_row.slug;
   end;
  end if;
  if v_activated and v_row.category='staff' then
   insert into public.club_staff_roles(club_id,profile_id,role)
   values(v_club,v_row.profile_id,v_row.role_key) on conflict(club_id,profile_id,role) do nothing;
   if v_row.role_key in ('doctor','physiotherapist') then
    update _swan_role_accounts set result='AKTİF: ihtisas etiketi; tıbbi yetki ayrıca verilmeli'
     where slug=v_row.slug;
   end if;
  end if;
 end loop;
 perform set_config('request.jwt.claim.sub',coalesce(v_previous_sub,''),true);
 insert into public.club_accountants(club_id,profile_id,status)
 select v_club,profile_id,'active' from _swan_role_accounts where category='accountant'
 on conflict(club_id,profile_id) do nothing;
 update _swan_role_accounts s set result=case when exists(select 1 from public.club_accountants a
  where a.club_id=v_club and a.profile_id=s.profile_id and a.status='active')
  then 'AKTİF: test kulübü mali defteri; sporcu üyeliği YOK'
  else 'BEKLİYOR: muhasebeci ilişkisi iptal edilmiş; otomatik yeniden açılmaz' end
 where category='accountant';
 insert into public.turf_field_managers(field_id,profile_id,status)
 select v_field,profile_id,'active' from _swan_role_accounts where category='turf' and role_key='manager'
 on conflict(field_id,profile_id) do nothing;
 update _swan_role_accounts set result='ATANDI: saha pasif; yönetici test sahasına bağlı'
 where category='turf' and role_key='manager';
 update _swan_role_accounts set result='BEKLİYOR: yöneticiden uygulama üzerinden süreli devir daveti gerekli'
 where category='turf' and role_key='delegate';
 insert into public.store_memberships(store_id,profile_id,role)
 select v_store,profile_id,role_key from _swan_role_accounts where category='store'
 on conflict(store_id,profile_id) do nothing;
 update _swan_role_accounts set result='ATANDI: test mağazası pending; onay/yayın yapılmadı' where category='store';

 if v_enable_federation_roles then
  insert into public.federation_roles(federation_id,profile_id,role,city_code,starts_on,ends_on)
  select v_federation_id,s.profile_id,s.role_key,
   case when s.role_key='provincial_rep' then v_city end,current_date,current_date+7
  from _swan_role_accounts s where category='federation' and not exists(
   select 1 from public.federation_roles f where f.profile_id=s.profile_id
    and f.federation_id=v_federation_id and f.role=s.role_key);
  select id into v_office from public.federation_offices
   where federation_id=v_federation_id and city_code=v_city;
  if v_office is null then
   insert into public.federation_offices(federation_id,city_code,name)
   values(v_federation_id,v_city,'[TEST] Rol testi il ofisi') returning id into v_office;
  end if;
  insert into public.federation_appointments(profile_id,office_id,duty,starts_on,ends_on)
  select s.profile_id,v_office,s.role_key,current_date,current_date+7
  from _swan_role_accounts s where category='appointment' and not exists(
   select 1 from public.federation_appointments a where a.profile_id=s.profile_id
    and a.office_id=v_office and a.duty=s.role_key);
  insert into public.referee_profiles(profile_id,license_number,badge_tier,sport_code,city_code)
  select profile_id,'TEST-'||slug,case when category='referee_tier' then role_key else 'national' end,
   v_sport,v_city from _swan_role_accounts where category in ('referee','referee_tier')
  on conflict(profile_id) do nothing;
  update _swan_role_accounts set result='ATANDI: hassas federasyon rolü; süre/iptal durumunu tablodan kontrol et'
   where category in ('federation','appointment');
  update _swan_role_accounts set result='ATANDI: TEST hakem profili; maç görevi ayrıca atanmalı'
   where category in ('referee','referee_tier');
 else
  update _swan_role_accounts set result='ATLANDI: hassas federasyon/hakem seçeneği kapalı; mevcut yetki değişmez'
   where category in ('federation','appointment','referee','referee_tier');
 end if;
 update _swan_role_accounts set result='BEKLİYOR: gerçek davet + kimlik onayı ile veli bağı kurulmalı'
 where category='parent';
 update _swan_role_accounts set result='BEKLİYOR: gerçek ferdi sporcu belgesi incelemesi gerekli'
 where category='individual';
 update _swan_role_accounts set result='BEKLİYOR: uygun topluluğa katıl; staff ayrıca yetkilendirilir'
 where category='community';
 update _swan_role_accounts set result='HAZIR: standart oturum; misafir testi için oturumu kapat' where category='viewer';
 -- Sonuç sorgusu başka bağlantıda da çalışır. Bu alanlar yetki kaynağı DEĞİLDİR.
 update auth.users a set raw_app_meta_data=coalesce(a.raw_app_meta_data,'{}'::jsonb)
  ||jsonb_build_object('seed_role_title',s.title,'seed_setup_result',s.result)
 from _swan_role_accounts s where a.id=s.profile_id;
 raise notice '45 test hesabı hazır. BEKLİYOR/ATLANDI satırları aktif rol DEĞİLDİR. Mevcut şifre ve banlar korundu.';
end
$seed$;
-- Bu SELECT, DO'dan bağımsız olarak da çalıştırılabilir; temp tablo okumaz.
select a.email,a.raw_app_meta_data->>'seed_role_title' as rol,
 a.raw_app_meta_data->>'seed_setup_result' as kurulum_durumu,a.id as profile_id,
 public._c1_has_identity(a.id) as kimlik_onayli,
 p.is_platform_admin as gercek_platform_yetkisi,
 coalesce(a.banned_until>clock_timestamp(),false) as giris_engelli
 from auth.users a join public.profiles p on p.id=a.id
 where a.raw_app_meta_data->>'seed_owner'='swansport-live-role-tests-v2'
 and a.email like '%@test.swansport.invalid'
 and a.id=md5('swansport-live-role-tests-v2/'||split_part(a.email,'@',1))::uuid
 order by a.email;
