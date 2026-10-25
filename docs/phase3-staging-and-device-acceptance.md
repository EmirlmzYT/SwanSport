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
