-- =============================================================================
-- SwanSport — 0028: YETKİ SIKILAŞTIRMA
--
-- Yeni özellik eklemez, RLS'i gevşetmez. Kullanıcı tarafından çağrılmaması
-- gereken fonksiyonların çalıştırma iznini kaldırır.
--
-- Sorun: PostgreSQL, `create function` sırasında EXECUTE iznini `PUBLIC`
-- sözde-rolüne verir. Supabase bu fonksiyonları REST üzerinden açtığı için
-- `security definer` bir bakım fonksiyonu, tanımlayanın yetkisiyle, anon
-- anahtarı olan herkes tarafından çağrılabilir hale gelir.
--
-- DİKKAT: İzni yalnızca `anon` ve `authenticated`'dan almak İŞE YARAMAZ.
-- O rollerin üzerinde doğrudan bir grant yoktur; erişimi `PUBLIC`'ten miras
-- alırlar. Bu yüzden aşağıda önce `public` yazıyor. (Buradaki `public`
-- şema değil, "herkes" anlamına gelen sözde-roldür.)
--
-- Fonksiyonlar SİLİNMEZ; SQL editöründen (postgres rolüyle) çalışmaya devam
-- eder, yalnızca uygulama üzerinden çağrılamaz.
--
-- Tamamını seçip çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- KRİTİK — yetki yükseltme.
-- Anon anahtarı olan herkes istediği hesabı platform yöneticisi yapabiliyordu.
-- Bu fonksiyon tamamen kaldırıldı; yönetici atama SQL editöründen yapılır.
drop function if exists public.seed_make_me_platform_admin(text);

-- Demo kurulumu ve temizliği — uygulamadan çağrılmasına gerek yok.
-- clear_demo_data dışarıya açık kalırsa veri kaybı kapısıdır.
revoke execute on function public.seed_demo_data(text) from public, anon, authenticated;
revoke execute on function public.clear_demo_data(text) from public, anon, authenticated;
revoke execute on function public.demo_target_user(text) from public, anon, authenticated;

-- Serbest bildirim yazıcısı — dışarıdan çağrılabilir olması sahte
-- bildirim/oltalama kapısıdır. Tetikleyiciler bunu içeriden çağırır.
revoke execute on function public.push_notification(uuid, text, text, text, uuid, text, uuid) from public, anon, authenticated;

-- Zamanlanmış hatırlatma işleri — bunları pg_cron çalıştırır.
-- Dışarıdan tetiklenirse kullanıcılara tekrar tekrar bildirim gider.
revoke execute on function public.send_fee_reminders() from public, anon, authenticated;
revoke execute on function public.send_attendance_reminders() from public, anon, authenticated;
revoke execute on function public.send_document_expiry_reminders() from public, anon, authenticated;
