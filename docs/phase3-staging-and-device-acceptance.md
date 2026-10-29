# Aşama 3 staging ve fiziksel cihaz kabulü

## Hazırlanan otomasyon

GitHub Actions içindeki **Phase 3 Staging Acceptance** yalnız elle çalışır ve
`staging` environment kullanır. Canlı SwanSport Supabase proje kimliğini
reddeder. Migration her zaman önce dry-run yapar; gerçek staging yazımı ayrıca
`apply_migrations` seçilmedikçe başlamaz.

Android işi staging Supabase ve staging Firebase ile imzalı APK üretir. iOS işi
staging Supabase kullanan imzasız bir önizleme üretir ve Firebase/APNs'i bilinçli
olarak kapalı tutar. Bu IPA açılış/gezinme için kullanılabilir; push kabulü
değildir. iOS push kabulü için Apple imzalı, gerçek staging Firebase/APNs
yapılandırmalı TestFlight paketi gerekir.

## GitHub staging secret sözleşmesi

- `STAGING_SUPABASE_URL`
- `STAGING_SUPABASE_ANON_KEY`
- `STAGING_PROJECT_ID`
- `SUPABASE_ACCESS_TOKEN`
- `STAGING_DB_PASSWORD`
- `STAGING_GOOGLE_SERVICES_JSON_BASE64`

Android imzalama için mevcut dört `ANDROID_*` repository secret'ı kullanılır.
Service-role anahtarı mobil derlemeye verilmez.

## Fiziksel kabul akışı

Her iki platformda staging hesaplarıyla şu kontroller yapılır: temiz kurulum ve
güncelleme, soğuk açılış, rol/hesap geçişi, ana gezinme ve deep link, bağlantı
kesilip gelince toparlanma, mesaj/rozet ayrımı, muhasebeci sporcu gizliliği,
veli-çocuk izolasyonu ve push'ın ön plan/arka plan/uygulama kapalı teslimi.

`docs/phase3-device-acceptance.template.json` kopyalanır; yalnız takma cihaz/test
adları ve GitHub run/artifact kimlikleri yazılır. Ad, e-posta, telefon, mesaj
metni, token veya kişisel ekran görüntüsü rapora konmaz. Tamamlanan rapor:

```bash
python tools/phase3_device_report.py path/to/phase3-device-report.json
```

Komut `22/22` vermeden Aşama 3 fiziksel kabulü tamamlanmış sayılmaz. İmzasız
iOS önizlemedeki üç push satırının `blocked` kalması beklenir; bunlar ancak
imzalı TestFlight paketiyle gerçek cihazda geçebilir.

## Bu turdaki sınır

Canlı Supabase'e migration uygulanmadı, production release üretilmedi ve mevcut
Ana Sayfa görünümü değiştirilmedi. Staging hesabı ile fiziksel Android/iPhone
erişimi dışarıdan sağlanmadan cihaz sonucu üretilemez.

Kaynak commit'i üzerindeki tam GitHub CI koşusu `40223132867` başarılıdır;
staging sırları olmadığı için staging workflow'u bilerek çalıştırılmamıştır.

## 2026-10-26 uygulama sonucu

- Ayrı Supabase staging projesi `hsfobmghsbtegiiqphpc` doğrulandı ve migration
  zinciri `40235896424` koşusunda başarıyla uygulandı.
- Dağıtım sonrası `40237030025` dry-run'ı `Remote database is up to date`
  sonucunu verdi.
- İlk temiz kurulumda 0028'in artık bulunmayan demo yardımcılarına koşulsuz
  `REVOKE` vermesi yakalandı. Eksik yardımcıları yeniden oluşturmadan koşullu
  kapatan regresyon eklendi.
- Android staging APK ve unsigned iOS staging IPA şu prerelease'tedir:
  <https://github.com/EmirlmzYT/SwanSport/releases/tag/staging-preview-1.0.5-62>
- APK SHA-256:
  `51ed1bc4c8ad09fdbafa4abb8c6a8bdce1984a6ecbb8942caaf58d448a66129a`
- IPA SHA-256:
  `5166526a8cf38a290d904ce7e7f51c3c53f184ab8e08a856994423cd37510a32`
- Her iki paket içinde staging URL'si bulundu, production Supabase ref'i
  bulunmadı. IPA `1.0.5+62`, CRC temiz ve Firebase plist içermiyor.
- Son tam CI `40237643738` başarılıdır. Gece yarısı UTC/İstanbul ayrışmasıyla
  kararsızlaşan federasyon tarih testleri ürünün İstanbul saatiyle hizalandı.

Fiziksel Android/iPhone kabulü yapılmadı. iOS IPA imzasızdır ve APNs/push kapalı
olduğu için iOS push kabulünün yerine geçmez.
