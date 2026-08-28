-- =============================================================================
-- SwanSport — Bootstrap: kendini platform yöneticisi yap + kulüp kurabilmen için
-- onaylı 2. kademe antrenör kimliği ver. 0004_roles_verification.sql'den SONRA.
--
-- 1. Aşağıdaki e-postayı kendi giriş e-postanla değiştir.
-- 2. SQL Editor → New query → yapıştır → Run.
-- =============================================================================

do $$
declare v_uid uuid;
begin
  select id into v_uid from auth.users where email = 'REPLACE_WITH_YOUR_EMAIL';
  if v_uid is null then
    raise exception 'Kullanıcı bulunamadı. Önce uygulamada giriş yap.';
  end if;

  -- Platform yöneticisi (tüm evrakları onaylayan sensin)
  update public.profiles set is_platform_admin = true where id = v_uid;

  -- Kulüp kurabilmen için onaylı 2. kademe antrenör kimliği
  if not exists (
    select 1 from public.profile_credentials
    where profile_id = v_uid and kind = 'coach' and coach_level = 2
  ) then
    insert into public.profile_credentials
      (profile_id, kind, coach_level, status, reviewed_by, reviewed_at)
    values (v_uid, 'coach', 2, 'approved', v_uid, now());
  end if;

  raise notice 'Platform yöneticisi + onaylı 2. kademe kimliği verildi (%).', v_uid;
end $$;

-- İpucu: kulüp oluşturduktan sonra "beklemede" olur. Kendi kulübünü onaylamak için:
--   select id, name, status from public.clubs;      -- kulüp id'sini bul
--   select public.approve_club('BURAYA_CLUB_ID');   -- aktifleştir
