-- =============================================================================
-- SwanSport — BOOTSTRAP (SETUP.sql'den SONRA + uygulamada giriş yaptıktan sonra)
-- Seni platform yöneticisi yapar + kulüp kurabilmen için onaylı 2. kademe verir.
--
-- 1. Aşağıdaki e-postayı UYGULAMAYA GİRİŞ YAPTIĞIN e-posta ile değiştir.
-- 2. SQL Editor → New query → yapıştır → Run.
-- =============================================================================

do $$
declare v_uid uuid;
begin
  select id into v_uid from auth.users where email = 'REPLACE_WITH_YOUR_EMAIL';
  if v_uid is null then
    raise exception 'Kullanıcı bulunamadı. Önce uygulamada kayıt ol / giriş yap.';
  end if;

  -- Profil satırı yoksa oluştur
  insert into public.profiles (id, full_name)
  values (v_uid, 'Yönetici')
  on conflict (id) do nothing;

  -- Platform yöneticisi
  update public.profiles set is_platform_admin = true where id = v_uid;

  -- Onaylı 2. kademe antrenör kimliği (kulüp kurabilmen için)
  if not exists (
    select 1 from public.profile_credentials
    where profile_id = v_uid and kind = 'coach' and coach_level = 2
  ) then
    insert into public.profile_credentials
      (profile_id, kind, coach_level, status, reviewed_by, reviewed_at)
    values (v_uid, 'coach', 2, 'approved', v_uid, now());
  end if;

  raise notice 'Tamam: platform yöneticisi + onaylı 2. kademe (%).', v_uid;
end $$;
