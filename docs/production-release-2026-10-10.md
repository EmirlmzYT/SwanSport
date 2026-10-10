# Üretim yayını — 2026-10-10

Kullanıcının canlı migration ve Cloudflare yayın talimatıyla tamamlandı. Ürün kaynağı `af653c4`; yeni ürün kodu yazılmadı. Önkontrol: `production-preflight-2026-10-10.md`.

## Canlı veritabanı

Üretim istemcisinin bağlandığı Supabase projesi, yönetim panelindeki `swanspor105` projesiyle eşleştirildi. Mevcut şema yalnız SELECT ile incelendi; 0076'ya kadar olan antrenman ve hesap bağlama fonksiyonları doğrulandı. Migration ledger bulunmadığından geçmiş uygulanmış varsayılmadı.

Kullanıcının test kaydı için belirttiği kulüp aidiyeti düzeltildi. UPDATE yalnız doğrulanan sporcu/profil/kulüp ve mevcut aktif yöneticilik eşleşmesinde çalıştı; tam bir satır etkilenmediğinde exception üreten ayrı işlem kullanıldı. Kulüpsüz sporcu sayısı **0**. Kişisel adlar ve kayıt UUID'leri bu raporda tutulmadı.

**0077–0104 arasındaki 28 migration sırasıyla uygulandı.** Her dosya kendi `BEGIN` / `COMMIT` sınırında ve `set local lock_timeout = '15s'` ile çalıştırıldı. Her commit sonrasında ilgili dosya adını döndüren başarı satırı okundu. 0099 enum işleminin commit'i 0100'dan önce doğrulandı. Dosya kaynakları değiştirilmedi; editöre aktarılan metin satır sonları normalize edilerek kaynakla karşılaştırıldı.

0081 öncesine aynı işlem içinde ek kilit ve mükerrer su kaydı kontrolü konuldu. Mevcut mükerrer kayıt olsaydı işlem veriye dokunmadan duracaktı. Böylece eski kayıt silme/birleştirme otomatik yapılmadı. Diğer migration'lar kaynak dosyalarıyla uygulandı. 0086/0094 dinamik RLS döngülerini, 0092/0093 şema öneksiz RLS ifadelerini editörün uyarı tarayıcısı tanımadı; kaynaklar incelenip kendi RLS tanımlarıyla çalıştırıldı. Sonkontrol bu tablolarda RLS'in açık olduğunu doğruladı.

Cron işleri kapatılmadı. Kilit hatası veya başarısız migration olmadı. Resmi programlar kendiliğinden yayımlanmadı; mevcut resmi/yayımlanmış program sayıları **0 / 0**.

## Canlı doğrulama

- Migration kaynaklarında oluşturulan tabloların tümünü kapsayan son tarama: **eksik tablo yok**.
- Denetlenen 26 yeni federasyon/diagnostic/beslenme/ekipman/kort/saha tablosu: **RLS eksiği yok**.
- Denetlenen hassas ve resmi tablolarda **anon SELECT izni yok**.
- Sonuç, kadro, veli ve kimlik dahil 13 ilgili RPC: security definer; **PUBLIC execute yok**. Public okuma RPC'leri yalnız anon/authenticated; özel veli/yazma RPC'leri yalnız authenticated; iki iç yardımcı istemcilere kapalı. Denetlenen fonksiyonlarda tek imza var.
- Gerçek üretim PostgREST anonim HTTP kontrolleri: **18/18 geçti**. Beş genel okuma RPC'si 200; on bir hassas tablo sorgusu ve iki özel/yazma RPC'si 401 / SQLSTATE 42501 döndürdü. Genel federasyon okumaları boş; aktif haber kaynağı okuması üç satır.
- Mevcut test hesabının gerçek `authenticated` rolü ve ilgili JWT claim'leriyle yalnız okuma testi yapıldı; işlem rollback edildi. Kendi kulüp üyeliği/sporcu kaydı okunuyor, takvim ve resmi CV sorguları çalışıyor. Kimlik doğrulanmış sayılmadı; eski aktif üyelik geçiş hakkı korundu. Bu, cihazdan giriş testi değildir.
- pg_net kurulu; Vault push anahtarı mevcut; 8 FCM aboneliği var. Resmi sonuç bildirim tetikleyicisi ve notifications Realtime yayını etkin. Cloudflare'da FCM_SERVICE_ACCOUNT, PUSH_SECRET ve VAPID yapılandırma adları mevcut. Anahtar değerleri okunmadı veya rapora yazılmadı; iki taraftaki değer eşleşmesi ve gerçek teslim bu kontrollerden kanıtlanamaz.

Anon test günlüğü: Git dışında `build/live-release-smoke.log`. Önceki ürün testleri (783 Flutter, 135 Dart, 88 SQL koşusu) `coach-guardian-result-verification.md` içinde; bu yayında aynı kaynak için yeniden tamamı çalıştırılmış gibi raporlanmaz.

## Cloudflare

- Proje: **swanspor**, ortam **Production**, dal **main**.
- Uygulama: https://swansport.pages.dev/
- Konsol: https://swansport.pages.dev/konsol/
- Sabit dağıtım: https://fb88bc82.swansport.pages.dev/
- Dağıtım kimliği: `fb88bc82-6c94-4796-96db-ff85f8fb76c5`.
- Kaynak commit: `af653c4`.

Uygulama ve konsol üretim web build'leri bu oturumda tekrar geçti. App'in eski gömülü konsol klasörü dışlanıp güncel ayrı konsol çıktısı eklendi; base href `/konsol/` doğrulandı. `apps/swansport_app` çalışma dizinindeki mevcut Pages Functions bundle'ı da yayımlandı. Wrangler: Worker compiled, 6 yeni/90 mevcut dosya, Functions bundle uploaded, **Deployment complete**. Üretim dağıtım listesinde kimlik/ortam/dal/commit doğrulandı.

SHA256:

- App main.dart.js: `28c2f0ad3cedd9ec228b7b632b241c1319f5de4d0c1398810a680e19b138ac32`
- Console main.dart.js: `a9ecde9ae126dda67c088dae6762e92250ee4b44cd48264415a04c2462de1a85`

Yerel paket: `build/release-2026-10-10-live`. Günlükler: `build/live-release-app-build.log`, `build/live-release-console-build.log`, `build/live-release-cloudflare.log`, `build/live-release-deployments.log`.

## Açık kabul testleri

Bu bağlantıda pages.dev üretim/sabit dağıtım HTTP istekleri TLS/DNS/bağlantı hatası veriyor; Edge de `ERR_SSL_PROTOCOL_ERROR` döndürdü. Sertifika koruması aşılmadı. Dolayısıyla canlı HTML/JS hash eşleşmesi, konsol derin bağlantısı ve hesaplı arayüz testi bu bilgisayardan doğrulanamadı. Cloudflare dağıtım başarısı bu testlerin yerine geçmez. Günlük: `build/live-release-http.log`.

Fiziksel Android cihazda **güncel Android istemcisiyle** veli hesabı, bildirim izni, ön plan/arka plan/kapalı uygulama teslimi, özel karne bağlantısı, sonuç düzeltmesi ve veli bağı kaldırma testleri açık. Bu oturum web/konsol yayınıdır; yeni APK oluşturulmadı. Gerçek kişilere test sonucu/bildirim üretilmedi. Başlangıç kullanıcı dosyaları korunur. Git push yapılmadı.
