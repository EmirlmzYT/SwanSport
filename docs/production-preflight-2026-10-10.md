# Canlı yayın önkontrolü — 2026-10-10

Güncelleme: Kullanıcının test kaydı aidiyetini netleştirmesinin ardından engeller giderildi; 0077–0104 canlıya uygulandı ve Cloudflare yayını tamamlandı. Son durum ve doğrulama sınırları `production-release-2026-10-10.md` içindedir. Aşağıdaki kayıt ilk önkontrolün tarihsel durumudur.

Kullanıcı canlı önkontrol, uygun migration'ları uygulama ve Cloudflare yayını için talimat verdi. Önkontrol veritabanında yalnız SELECT sorgularıyla yapıldı. Migration veya deployment başlatılmadı.

## Doğrulanan durum

- Üretim istemcisinin Supabase URL'si, yönetim panelinde açılan `swanspor105` projesiyle eşleşiyor.
- `supabase_migrations.schema_migrations` mevcut değil; migration geçmişi bu tablodan doğrulanamıyor. Eksik geçmiş tamamlanmış kabul edilmedi.
- `federations`, `federation_appointments`, `athlete_sport_registrations` mevcut değil. `my_identity_gate()`, `federation_publish_program(uuid,boolean)`, `public_sport_programs()` mevcut değil. `profile_credentials.verified_national_id` sütunu yok.
- Daha eski şema işaretleri de eksik: `diagnostic_issues`, `season_setup_runs`, `court_waitlist`, `turf_duty_delegations`, `prepare_attendance_offline(uuid)` ve `athlete_development_report(uuid,date,date)`. Yayın öncesi kontrol yalnız 0094 sonrasıyla sınırlandırılamaz.
- `athletes.club_id IS NULL` olan **1** kayıt var. Hesaba bağlı ve aynı hesabın aktif kulüp yöneticiliği var; veli bağlantısı yok. Yöneticilik sporcunun kulüp aidiyetini kanıtlamadığı için otomatik eşleştirme yapılmadı. Kişisel adlar ve UUID'ler bu rapora eklenmedi.
- 0100 migration'ı bu kayıt bulunduğunda açıkça exception üretir. Kaydı silmek, rastgele kulüp atamak veya migration kontrolünü kaldırmak uygulanmadı. Kullanıcıya doğru kulüp aidiyeti soruldu.
- Wrangler OAuth oturumu kullanılabilir. Doğru Pages projesi `swanspor`, alan adı `swansport.pages.dev`; diğer `swansport` projesi farklı alan adındadır.

## Yerel hazırlık

Ürün kaynaklarında `af653c4` sonrası fark yok. Önceki test/build kanıtı `docs/coach-guardian-result-verification.md` içinde. Bu önkontrol yeni ürün testi veya fiziksel cihaz testi değildir.

Önceki üretim build çıktıları Git dışında `build/release-2026-10-10` klasörüne alındı; eski gömülü konsol dışlanıp ayrı konsol çıktısı eklendi. Konsol base href `/konsol/`.

- App `main.dart.js` SHA256: `28c2f0ad3cedd9ec228b7b632b241c1319f5de4d0c1398810a680e19b138ac32`
- Console `main.dart.js` SHA256: `a9ecde9ae126dda67c088dae6762e92250ee4b44cd48264415a04c2462de1a85`

Bu paket yayımlanmadı. Şema engeli çözüldükten sonra nihai kaynak/build güncelliği tekrar kontrol edilmelidir. Canlı migration'lar dosya başına ayrı işlem ve `set local lock_timeout = '15s'` ile uygulanmalı; 0099 enum işlemi 0100'dan önce commit edilmelidir. Eski migration'lar körlemesine yeniden uygulanmamalıdır.

## Kalanlar

1. Kulüpsüz kaydın gerçek aidiyetini netleştir; veri kaybı olmadan, doğrulanmış bilgiyle çöz.
2. Önceki şema eksiklerinin kapsamını ve gerekli migration sırasını doğrula.
3. Uygun migration'ları dosya başına ayrı işlemle uygula; ACL/RLS ve RPC sonkontrollerini yap.
4. App, konsol ve mevcut Pages Functions paketini üretime yayımla, deployment kimliği ve HTTP davranışını doğrula.
5. Fiziksel Android cihazda veli hesabıyla ön plan/arka plan/kapalı uygulama FCM, düzeltme ve veli bağı kaldırma testlerini yap.
