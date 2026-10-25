# Kaynak, yayın ve kabul matrisi

Güncelleme: 2026-10-25. **Ana Sayfa görünümü ve sosyal spor ağı yönü korunur.**

Bu belge ile üretilen JSON farklı kanıtları taşır. `python tools/release_matrix.py
--output build/release-matrix.json` mevcut commit, çalışma alanının değişiklik
durumu, uygulama sürümü ve tüm migration dosyalarının SHA-256 değerlerini
üretir. CI çıktısı ilgili commit'in artifact'idir. Canlıya kurulduğunu veya
fiziksel cihazda kabul edildiğini kendiliğinden iddia etmez.

| Katman | Bilinen kaynak/kanıt | Güncel kabul |
|---|---|---|
| Mobil kaynak | pubspec sürümü 1.0.5+62; paket kaynak commit'i `217e84bc` | Android `40214737143`, iOS `40214771539` başarılı |
| Konsol kaynak | Aynı workspace; hesap/kulüp izolasyon testleri | Yerel test/build sonucu güvenilirlik raporunda |
| SQL kaynak | 139 migration; son dosya mali dönem tetikleyicisi düzeltmesi | Parse ve temiz PostgreSQL zinciri geçti; canlı karşılaştırılmadı |
| Üretim SQL | Son açık tarihsel kanıt: 0107, 2026-10-10 | Güncel durum **doğrulanmadı**; eski kayıt güncel ledger değildir |
| Üretim web/konsol | Son tarihsel dağıtım kanıtı docs/production-rollout-0107.md | Güncel uzak JS/hash **doğrulanmadı** |
| Android/iOS paket | GitHub prerelease `preview-1.0.5-62` | APK/IPA üretim ve paket bütünlüğü geçti; fiziksel cihaz **doğrulanmadı** |
| İzole gerçek Auth/roller | Beş GoTrue hesabı + PostgREST/RLS, CI `40212637923` | Altı Aşama 2 senaryosu **geçti**; harici gerçek kulüp UAT'si bekliyor |
| Fiziksel push teslimi | Sağlayıcı kabulü telefon teslimi değildir | Android/iOS cihaz kabulü **bekliyor** |

## Yayın kaydı doldurma sözleşmesi

Her yayın için tek bir kayıt tut: tarih, sorumlu, kaynak commit (dirty=false),
CI koşu bağlantısı, migration dosya/hash listesi ve ortam ledger karşılaştırması,
web/konsol dağıtım kimliği, APK/IPA sürüm-build/hash, açılan özellik kademeleri,
rol/cihaz kabul kanıtı ve geri çekme adımı. Sır, token, çocuk adı veya gerçek
hesap UUID'si rapora yazılmaz. Eski migration dosyaları değiştirilmez.

Yeni güvenilirlik migration'ları önce staging/yerelde dosya başına işlem ve
15s lock_timeout ile uygulanır. Fonksiyon ACL/RLS, pg_net response şeması ve
cron kaydı kontrol edilmeden production'a geçilmez. `process_push_deliveries`
yalnız backend service_role/scheduler içindir; uygulama anahtarı olarak
service_role dağıtılmaz. pg_cron olmayan ortamda scheduler ayrıca kurulmadan
yanıt işleme/tekrar deneme kabulü verilmez.

## Push durumlarının anlamı

`pending` sırada; `in_flight` pg_net isteği işlem sonrası gönderecek;
`accepted` sağlayıcı kabul etti; `retry` sağlayıcı açık geçici ret verdi;
`failed` bilinen kalıcı ret/konfigürasyon hatası veya üç deneme sınırı;
`unknown` zaman aşımı, eksik/bozuk yanıt veya taşıma belirsizliği;
`skipped` tercih/kayıt sahipliği değişti; `expired` gönderim penceresi doldu.

**accepted fiziksel teslim değildir.** Unknown otomatik yeniden gönderilmez;
aksi aynı cihazda çift bildirim üretebilir. Bilinen geçici 429/500/503 retleri
en fazla üç deneme, 60/120 saniye bekleme ile denenir. Canlı skorun penceresi
60 saniye, diğer bildiriminki bir gündür. Başarılı cihaz tekrar denenmez.
FCM'de yalnız UNREGISTERED detayı token temizler; proje/config 404'ü temizlemez.
Eski sender'ın sınıflandırma alanı olmayan 404 cevabı da token silemez;
Cloudflare sender güncellemesi SQL geçişinden önce yayımlanmalıdır.
Hesap/cihaz kaydı revizyonu değiştiyse gecikmiş sonuç yeni kaydı silemez.
Kuyruktaki tercihler, maç takibi, DM engeli ve resmi sonuç veli bağı tekrar
kontrol edilir; taşıyıcıya zaten verilmiş bir push
sonraki hesap değişiminde geri çağrılamaz. Terminal ledger kayıtları 30 gün
sonra temizlenir; gövde/token/anahtar ledger'a yazılmaz.

## 1.0.5+62 test paketleri

GitHub prerelease: `preview-1.0.5-62`. İmzalı APK SHA-256
`8cca4d8385d7331908139410a13404b67556d20c9f8746ed3cc82fbf57cc27ce`;
imzasız IPA SHA-256
`82d23938a313439a249d61b9c8bd8762e83f9b83c854a7a29da72fb5bcfe8776`.
IPA `com.swansport.app`, sürüm `1.0.5`, build `62`; Mach-O ve ZIP sağlam,
GoogleService yer tutucusu ve dağıtım imzası yok. IPA yalnız sideload testidir;
TestFlight/App Store veya çalışan APNs kanıtı değildir.
