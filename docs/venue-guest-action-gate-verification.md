# Misafir saha/partner vitrini ve işlem kapısı — 2026-10-10

## Uygulanan davranış

`/kortlar`, `/halisahalar`, `/partner-ara`, `/oyuncu-aranan` rota sözleşmeleri korunur. Misafir tesisleri, müsait saatleri ve açıkça halka yayımlanmış partner davetlerini okuyabilir. Aynı detay ekranı hesaplı ve misafir kullanıcıya hizmet eder.

Rezervasyon/saat isteği, bekleme listesi, partner ilanı/katılımı ve kort check-in işlemleri önce `SwanAccess.decisionFor` üzerinden değerlendirilir. Misafire hesap alt sayfası, telefon/kimliği doğrulanmamış hesaba doğrulama alt sayfası açılır. Geri dönüşte işlem otomatik tekrarlanmaz. Mevcut `/dogrulama` ekranına SMS kodu isteme/onaylama bölümü eklendi; tüm Auth çağrıları ortak veri servisindedir.

Yeni `0107_venue_guest_action_gate.sql` için önkoşul mevcut migration zinciridir. Depodaki gerçek rezervasyon RPC'leri `claim_slot` ve `request_turf_slot` adlarını taşır; `reserve_court_slot` diye ikinci rezervasyon sistemi oluşturulmadı. Halı saha isteği, 0040'taki mevcut **gerçek DM → bildirim** hattını korur; kesin rezervasyon değildir. Tekrarlanan istek ikinci mesaj oluşturmaz; yönetici bulunmayan veya iletişim kurulamayan sahada sahte başarı dönmez.

## Sunucu güvenliği

- Telefon kanıtı `auth.users.phone` ve `phone_confirmed_at`; kimlik kanıtı mevcut onaylı kimlik belgesidir (`_c1_has_identity`). `profiles.verification_tier`, rol veya platform yöneticiliği kanıt değildir. Boş/onaysız telefon ve Supabase anonim Auth kullanıcısı kapıyı açmaz.
- Ortak özel yardımcı, korunan RPC'lerin gövdesinde çalışır. `PUBLIC`, `anon`, `authenticated` execute izinleri önce kaldırılır; yazma RPC'leri yalnız authenticated'a açılır. Özel yardımcılar istemciye açılmaz. Doğrudan profil seviyesi yükseltme reddedilir; eski yanlış beyanlar işlem izni vermez.
- Bekleme sırası/teklif/iptal davranışı korunur. Doğrulama geri alınınca kabul/check-in/yeni işlem engellenir; kendi isteğini iptal etme/yanıtı reddetme çıkışları açık kalır.
- Anonim tablolar sportif kişi kayıtlarını vermez. Kort şeridi/oyun listesi misafire profil UUID'si/adı taşımaz; halı saha iç notu yalnız yetkiliye döner. Özel kişisel sağlayıcılar misafirken servis/RPC oluşturmaz.
- Eski partner istekleri `is_public=false` kalır. Yeni yayın açık tercih ister. Halka açık projeksiyon yalnız ilan kimliği, branş, şehir ve zamanları taşır; ad, profil UUID'si, telefon ve koordinat yoktur. Süresi geçmiş, engellenmiş, yasaklı veya doğrulaması düşmüş ilan eylem için kullanılamaz. `Oynayalım` açık daveti mevcut eşleşme hattıyla atomik kabul eder; ikinci kişi aynı isteği alamaz.
- Açık ilan kimliklerinin başka kişinin bekleyen pinglerini iptal etmesine yol açan eski `cancel_partner_request` yolu sahiplik kontrolüyle kapatıldı. NULL kabul/ret değeri artık doğrulama kontrolünü atlayamaz.

## Tesis bilgileri

Mevcut tesis tablolarına isteğe bağlı `surface_type` ve en fazla sekiz `photo_paths` alanı eklendi. Fotoğraflar mevcut public `post-media` bucket yollarından okunur. İkinci bucket/galeri sistemi veya örnek veri yoktur. Alanlar doluysa detayda zemin/fotoğraflar görünür; boşsa bilgi uydurulmaz. Bu çalışma ayrı bir tesis medya yükleme/yönetim ekranı içermez.

Koordinatı olan tesisin detayında hesapsız harita bağlantısı vardır. Harita kullanıcının dokunmasıyla dış uygulamada açılır. Yakınlığa göre sıralama konumu artık sayfa açılırken otomatik istemez; kullanıcı `Yakınımdakiler` eylemini seçer.

## Doğrulama

- **402 veri + 368 uygulama + 50 konsol = 820 Flutter testi başarılı.** Loglar: `build/venue-data-full-final.log`, `build/venue-app-full-final.log`, `build/venue-console-full.log`.
- Dar misafir/kimlik/saha/rota widget koşusu: **45/45**. Gerçek ekranlarda anonim saat görüntüleme ve eylem kapısı, telefon/kimlik geçişi, partner okuma/ping, OTP hata/tekrar, fotoğraf/zemin, boş metadata ve dar koyu ekran sınandı. `build/venue-app-focused-final.log`.
- `node --test tools/venue_guest_gate_sql_test.mjs tools/saha_operations_sql_test.mjs`: **21/21** gerçek PostgreSQL/PGlite senaryosu. Anon read/write ACL, sahte seviye, NULL, telefon/kimlik iptali, RLS, özel ilan gizliliği, yayın tercihi, eşleşme/tek bildirim, bekleme sırası, DM/engel/yönetici ve idempotent migration sınandı. `build/venue-sql-final.log`.
- `flutter analyze packages/swansport_data apps/swansport_app apps/swansport_console`: **0 hata, 5 kapsam dışı mevcut uyarı**, 3192 stil info. Uyarılar role_context_switcher/marketplace importları, konsol marketplace count, veri marketplace raw Map ve eski social test List çıkarımıdır. `build/venue-full-analyze-final.log`.
- Migration parse: **107/107**; SSS kapsamı **39/39**; `git diff --check` başarılı.

Flutter koşuları ilgili paket/uygulama dizininde `flutter --no-version-check test --no-pub` ile çalıştı. Uygulamada ayrıca `--dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=` verildi; üretim servisine bağlanılmadı.

Graph 2026-10-07 indeksinde ilgili kaynaklar güncel/izlenmiş değildi. Sembol/iz/kapsama sorgularından sonra gerçek kaynaklar, migration'lar ve davranış testleri esas alındı.

## Canlıya geçiş ve açık kontroller

Bu görev **canlı SQL veya deploy yapmadı**. Yeni istemci öncesinde bekleyen 0105/0106 ve 0107 sırasıyla, dosya başına ayrı işlem ve `set local lock_timeout = '15s'` ile uygulanmalı. Tesis sorguları yeni metadata sütunlarını kullanır; 0107 öncesinde yeni istemci yayımlanmamalı.

SMS teslimi için canlı Supabase Auth SMS sağlayıcısı/yapılandırması gerekir. Gerçek numaraya SMS teslimi, fiziksel cihazda OTP ve dış harita açılışı, hesaplı canlı UAT ve iki gerçek bağlantıyla eşzamanlı yarış bu yerel testlerin kanıtı değildir. Teslim hatası istemcide açık gösterilir; onay uydurulmaz. Fotoğraf/zemin görünümü gerçek tesis verisi dolduruldukça kullanılır.

Başlangıçtaki generated Flutter metadata ve kullanıcı yol haritası değişiklikleri görev commit'inin dışındadır.
