# 0105–0107 üretim geçişi — 2026-10-10

Kullanıcı migration, Cloudflare yayını ve canlı kontrolleri yetkilendirdi. Son durum: 0105–0107 canlıya uygulandı; Cloudflare Production/main yayını tamamlandı. Yayın kaynağı `2cad676`. SMS sağlayıcı hesabı olmadığı için gerçek telefon doğrulaması ve TLS bağlantı sorunu nedeniyle canlı UI kabul testi açık. Aşağıdaki ilk bölümler tarihsel önkontroldür.

## Doğrudan doğrulanan durum

- Cloudflare OAuth kullanılabilir; swanspor Production/main son dağıtımı `fb88bc82-6c94-4796-96db-ff85f8fb76c5`, kaynak `af653c4`.
- Supabase CLI `projects list`, `AccessTokenRequiredError` döndürüyor. Yönetim oturumu yok; kullanıcı kendi terminalinde `npx supabase login` ile giriş yapmalı. Sır sohbete veya depoya yazılmamalı.
- Üretim Auth `/auth/v1/settings`: HTTP 200, `external.phone=false`. Telefon sağlayıcısı etkin değil; bu sonuç gerçek SMS tesliminin çalıştığını göstermez. Sağlayıcı hesabı/yapılandırması ve fiziksel telefon testi gerekir.
- Üretim PostgREST `courts?select=id,surface_type,photo_paths&limit=0`: HTTP 400, SQLSTATE `42703`. Yeni istemcinin gerektirdiği sütunların eksik olduğu doğrulandı. 0105/0106'nın uygulanıp uygulanmadığı bu sorgudan çıkarsanamaz; yönetim erişimiyle ayrı kontrol gerekir.
- Tarayıcı aracı zaman aşımına uğradı. Windows kontrol aracı mevcut URL'yi güvenle belirleyemediği için durduruldu; bu engel aşılmadı.

## Kalan uygulama sırası

Üretim app ve konsol web build'leri başarıyla tamamlandı (exit 0); üretim proje kimliği ve konsol `/konsol/` base href doğrulandı. Günlükler `build/rollout-0107-app-build.log` ve `build/rollout-0107-console-build.log`. Mevcut CupertinoIcons font uyarısı sürüyor. App ve konsol ayrı çıktılardan birleştirildi; eski gömülü konsol dışlandı. Hazır paketin yolu Git dışındaki `build/rollout-0107-release-path.txt` dosyasında; henüz yayımlanmadı.

SHA256:

- App: `ecdccef36b5e9e110975bb1298713b69797871f93eaa92519d30de16afc3fa36`
- Konsol: `39c211c1dc94028ce4038259dce05b0ae8126f71f8003215371a14da62ad3a6f`

1. Yönetim oturumuyla gerçek şema durumunu kontrol et.
2. Eksik 0105, 0106, 0107 dosyalarını sırayla, dosya başına ayrı işlem ve 15 saniye lock_timeout ile uygula. Tüm zinciri tek işlemde çalıştırma.
3. Fonksiyon imzalarını, PUBLIC/anon/authenticated izinlerini, misafir okumalarını ve doğrulamasız eylem reddini kontrol et.
4. Üretim app/konsol paketini mevcut Pages Functions ile birleştir, Cloudflare'ye yayımla; dağıtım listesi ve canlı içerikle doğrula.
5. SMS sağlayıcısı kurulduktan sonra gerçek telefonda kod teslimi, doğrulama ve korunan eylemi test et. Fiziksel cihaz testi yapılmadan tamamlandı deme.

Bu kontrol noktasında canlı SQL veya yeni Cloudflare dağıtımı yapılmadı. Başlangıç kullanıcı dosyaları korunur.


## Sonraki kontrol noktası — yönetim girişi sonrası

Kullanıcı CLI girişini tamamladı. Doğru canlı proje `swanspor105` / `gokkimnokigqxmbppvle`, ACTIVE_HEALTHY. Önkontrolde 0105/0106/0107 işaretlerinin üçü de yoktu; C1 ve mevcut antrenman temeli vardı. Migration ledger yoktu.

0105 ve 0106 ayrı işlemlerde başarıyla commit edildi. 0107 ilk denemesi SSS `audience='all'` nedeniyle `23514` ile bütünüyle rollback oldu. Canlı ve 0069 şema sözleşmesi `everyone` gerektiriyor. Kaynak 0107 bu değere düzeltildi; yeni SQL test fixture'ına gerçek `faq_audience_check` eklendi. 21/21 SQL testi tekrar geçti. Düzeltilen 0107 ayrı işlemde başarıyla commit edildi. Cron kapatılmadı; her işlem 15s lock_timeout kullandı.

Sonkontrol: 17 RPC'de tek imza, security definer ve PUBLIC execute kapalı; iç yardımcılar istemcilere kapalı. 15 tabloda RLS açık; yalnız halka açık iki tesis tablosu anon SELECT alıyor, diğer 13'ü kapalı. Gerçek anonim PostgREST kontrolleri 25/25 geçti. Bir test isteğinin parametre adı p_start yerine gerçek p_starts_at olarak düzeltildi; yeniden koşu geçerli kanıttır. Mevcut doğrulanmamış bir hesabın authenticated rolü/JWT claim'leriyle yazma reddi sınandı; işlem rollback edildi, gerçek rezervasyon/ilan/bildirim oluşturulmadı. Bu bir cihazdan giriş testi değildir.

107 migration parse ve SSS 39/39 başarılı. SQL/test dışındaki Dart ürün kaynakları değişmedi; hazır üretim paketinin kaynak güncelliği korunur. Cloudflare yayını bir sonraki adımdır. Önceki engel kayıtları tarihsel önkontroldür; veritabanı erişimi ve migration engeli giderildi. SMS sağlayıcısı/gerçek teslim testi hâlâ açık.


## Tamamlanan Cloudflare yayını

- Proje: `swanspor`; ortam `Production`; dal `main`; kaynak `2cad676`.
- Dağıtım: `45da5493-378c-449f-b950-6707e1b2ff28`.
- Uygulama: https://swansport.pages.dev/
- Konsol: https://swansport.pages.dev/konsol/
- Sabit dağıtım: https://45da5493.swansport.pages.dev/

Wrangler Worker derlemesini, Functions bundle yüklemesini ve Deployment complete sonucunu bildirdi (exit 0). Üretim dağıtım listesinde ortam/dal/kaynak/kimlik doğrulandı. Günlükler: `build/rollout-0107-cloudflare.log`, `build/rollout-0107-deployments.log`. Dört arketipin canlı SQL metrik doğrulayıcıları geçerli örnekleri kabul etti; eksik payload/config reddedildi. Dört ilgili SSS satırı aktif; eski özel partner istekleri yayımlanmadı (halka açık istek sayısı 0).

## Açık kabul testleri ve kullanıcıdan gereken

Kullanıcı hazır SMS sağlayıcı hesabı olmadığını bildirdi. Canlı Auth telefon sağlayıcısı kapalı; bu ayar tek başına açılmadı, örnek/sahte SMS kullanılmadı. Telefon doğrulama teslimi için önce gerçek sağlayıcı hesabı ve Supabase Auth SMS yapılandırması gerekir. API anahtarı sohbete/depoya yazılmamalı; kullanıcı doğrudan sağlayıcı ayarına girmeli. Onaylı kimlik yolu mevcut kapı sözleşmesine göre kullanılabilir.

Üretim ve sabit dağıtımın app/konsol HTML/JS isteklerinin sekizi de bu ağda `ERR_SSL_WRONG_VERSION_NUMBER` verdi. TLS koruması aşılmadı. Dağıtım listesi doğrulandı ama canlı sayfanın yüklenmesi ve uzak JS hash eşleşmesi doğrulanamadı. Günlük: `build/rollout-0107-http.log`. Gerçek kullanıcı/telefonla SMS, hesaplı arayüz ve fiziksel cihaz testleri açık. Web/konsol yayını Android APK güncellemesi değildir; bu oturum APK release üretmedi.

SQL düzeltmesi ve bu rapor GitHub'a kaydedilir. Başlangıç metadata ve kullanıcı yol haritası commit dışında korunur; CLI'nın ürettiği supabase/.temp dosyaları yayımlanan kaynak commit'ine alınmaz.
