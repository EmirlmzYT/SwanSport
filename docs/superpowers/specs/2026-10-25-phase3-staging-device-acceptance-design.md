# Aşama 3 — staging ve fiziksel cihaz kabul tasarımı

## Amaç

Üretim verisine dokunmadan gerçek cihaz kabulüne hazırlanmak. Ana Sayfa ve
ürün arayüzü kapsam dışıdır.

## Kararlar

- Derleme zamanı Supabase ayarı verilmezse uygulama fixture modunda kalır;
  kaynak kodda canlı backend varsayılanı bulunmaz.
- GitHub `staging` environment içindeki ayrı Supabase proje kimliği kullanılır.
  Canlı proje kimliği doğrulayıcı tarafından reddedilir.
- Migration önce `db push --dry-run` ile gösterilir. Gerçek staging yazımı ancak
  elle başlatılan işte `apply_migrations=true` seçilirse yapılır.
- Android staging paketi ayrı Firebase yapılandırması ister. iOS önizleme
  imzasız ve push kapalı üretilir; gerçek APNs kabulü imzalı staging/TestFlight
  paketi gerektirir.
- Fiziksel kabul sonuçları kişisel veri/not içermeyen, makinece doğrulanan JSON
  raporuyla kaydedilir. Kanıt yoksa sonuç `pass` sayılamaz.

## Güvenlik sınırı

Service-role anahtarı mobil pakete girmez. CI yalnız publishable/anon anahtarı
derlemeye geçirir; Supabase erişim tokenı ve veritabanı parolası yalnız migration
adımında GitHub secret olarak kullanılır. Canlı SQL bu çalışmada uygulanmaz.
