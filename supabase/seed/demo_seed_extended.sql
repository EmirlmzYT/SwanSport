-- =============================================================================
-- SwanSport — Genişletilmiş demo veri (duyuru, etkinlik, fatura, sağlık,
-- tesis, belge). 0003_extended.sql UYGULANDIKTAN sonra çalıştır.
--
-- 1. Uygulamada giriş yap + Kadro’dan bir kulüp oluştur (yönetici olursun).
-- 2. Aşağıdaki e-postayı kendi giriş e-postanla değiştir.
-- 3. SQL Editor → New query → yapıştır → Run.
--
-- Yönetici olduğun İLK kulübe demo veri ekler. Sporcu varsa fatura/sağlık
-- kayıtları onlara bağlanır. Tekrar çalıştırmadan önce tabloları temizle.
-- =============================================================================

do $$
declare
  v_email text := 'REPLACE_WITH_YOUR_EMAIL';
  v_uid  uuid;
  v_club uuid;
  v_ath1 uuid;
  v_ath2 uuid;
begin
  select id into v_uid from auth.users where email = v_email limit 1;
  if v_uid is null then
    raise exception 'Kullanıcı bulunamadı: %. Önce giriş yap.', v_email;
  end if;

  select club_id into v_club
  from public.club_memberships
  where profile_id = v_uid and role = 'club_admin' and status = 'active'
  order by created_at
  limit 1;
  if v_club is null then
    raise exception 'Yönetici olduğun kulüp yok. Önce uygulamada kulüp oluştur.';
  end if;

  -- İlk iki sporcuyu bul (varsa fatura/sağlık kayıtlarını bağlamak için)
  select id into v_ath1 from public.athletes where club_id = v_club order by first_name limit 1;
  select id into v_ath2 from public.athletes where club_id = v_club order by first_name offset 1 limit 1;

  -- Duyurular
  insert into public.announcements (club_id, author_id, title, body, pinned) values
    (v_club, v_uid, 'Tesis Bakım Çalışması', 'Salon B bugün 14:00–16:00 arası periyodik bakımdadır.', true),
    (v_club, v_uid, 'Antrenman Saati Değişikliği', 'Yarınki antrenman 18:00’e alınmıştır.', false),
    (v_club, v_uid, 'Aidat Hatırlatması', 'Ağustos aidat ödemeleri için son gün 25 Ağustos.', false);

  -- Etkinlikler (yaklaşan)
  insert into public.events (club_id, title, place, kind, starts_at, ends_at) values
    (v_club, 'U-16 Erkek Antrenman', 'Caferağa Spor Salonu', 'training', now() + interval '1 day' + interval '17 hour', now() + interval '1 day' + interval '19 hour'),
    (v_club, 'Veli Bilgilendirme Toplantısı', 'Online', 'meeting', now() + interval '2 day' + interval '19 hour', now() + interval '2 day' + interval '20 hour'),
    (v_club, 'U-18 Hazırlık Maçı', 'Kadıköy Spor Salonu', 'match', now() + interval '3 day' + interval '20 hour', now() + interval '3 day' + interval '21 hour');

  -- Faturalar
  insert into public.invoices (club_id, athlete_id, label, amount, status, period) values
    (v_club, v_ath1, 'Ağustos aidatı', 1500, 'paid', '2026-08'),
    (v_club, v_ath2, 'Ağustos aidatı', 1500, 'pending', '2026-08'),
    (v_club, null,  'Salon kira gideri', 8000, 'paid', '2026-08');

  -- Sağlık kayıtları
  if v_ath1 is not null then
    insert into public.injuries (club_id, athlete_id, status, note) values (v_club, v_ath1, 'fit', 'Sağlık raporu geçerli');
  end if;
  if v_ath2 is not null then
    insert into public.injuries (club_id, athlete_id, status, note) values (v_club, v_ath2, 'pending', 'Sağlık raporu bekliyor');
  end if;

  -- Tesisler
  insert into public.facilities (club_id, name, kind, occupancy, status) values
    (v_club, 'Caferağa Spor Salonu', 'Basketbol · Kapalı', 88, 'Yoğun'),
    (v_club, 'Salon B', 'Antrenman · Kapalı', 35, 'Müsait'),
    (v_club, 'Açık Saha 1', 'Kondisyon · Açık', 10, 'Müsait');

  -- Belgeler
  insert into public.documents (club_id, name, kind, size_label) values
    (v_club, 'Lisans Belgeleri', 'folder', '18 dosya'),
    (v_club, 'Antrenman Planı Q3.pdf', 'pdf', '2.4 MB'),
    (v_club, 'Turnuva Kadrosu.xlsx', 'xls', '88 KB');

  raise notice 'Demo veri eklendi (kulüp %).', v_club;
end $$;
