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

-- Bazı eski kurulumlarda bakım/demo fonksiyonları SQL Editor seed'inden gelir;
-- temiz kurulumda hiç bulunmaz. REVOKE eksik imzada 42883 verdiği için yalnız
-- gerçekten var olan imzaları kapat. Retired yardımcıları yeniden oluşturma.
do $$
declare
  signature text;
begin
  foreach signature in array array[
    'public.seed_demo_data(text)',
    'public.clear_demo_data(text)',
    'public.demo_target_user(text)',
    'public.push_notification(uuid,text,text,text,uuid,text,uuid)',
    'public.send_fee_reminders()',
    'public.send_attendance_reminders()',
    'public.send_document_expiry_reminders()'
  ] loop
    if to_regprocedure(signature) is not null then
      execute format(
        'revoke execute on function %s from public, anon, authenticated',
        signature
      );
    end if;
  end loop;
end
$$;
