# 0105–0107 üretim geçişi — 2026-10-10

Kullanıcı migration, Cloudflare yayını ve canlı kontrolleri yetkilendirdi. Ürün kaynağı `9fa3bad`. Bu kayıt yayın başarısı değildir.

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

