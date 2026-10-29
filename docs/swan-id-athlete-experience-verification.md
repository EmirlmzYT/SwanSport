# Swan ID ve sporcu deneyimi paketi — yerel doğrulama

## Kapsam

`0132_swan_identity_experience.sql` Swan ID, süreli QR doğrulaması, özel video
vitrini, gelişim çizelgesi, etkinlik hazırlığı, olumlu takım rozetleri, dijital
maç kartı ve modelsiz Swan Asistan için ilk yerel sözleşmeyi kurar. Yedi özellik
ayrı bayrakla `admins` kademesinde başlar.

Mobil uygulama `/swan-id`, `/swan-id/dogrula/<token>`, `/swan-asistan` ve
`/mac-kartim/<uuid>` rotalarını içerir. Veri erişimi
`packages/swansport_data/lib/src/swan_experience.dart` üzerinden yapılır;
widget katmanında doğrudan Supabase çağrısı yoktur.

## Güvenlik sınırları

- Yeni tablolar RLS açık ve doğrudan istemci tablo yetkileri kapalıdır.
- Yetkili işlemler dar `security definer` fonksiyonlarıyla yapılır; `PUBLIC`
  ve `anon` çalıştırma izinleri kaldırılır.
- Anonim QR yanıtı yalnız sabitlenmiş kart alanlarını döndürür. Ham profil UUID,
  doğum tarihi, iletişim, sağlık, belge ve disiplin verisi dönmez.
- Çocuk kartı ve videosunda veli onayı; keşfet videosunda ayrıca kulüp onayı
  gerekir.
- Video kovası özeldir. Yayımlanan kayıtta yalnız Storage yolu tutulur ve
  istemci görüntüleme sırasında kısa ömürlü imzalı URL ister.
- Takım rozeti tamamlanmış etkinlik ve gerçek katılım ister; kendine gönderme,
  engellenmiş hesap, tekrar ve etkinlik kotası sunucuda reddedilir.
- Dijital maç kartı yalnız resmi maç başlığı ve onaylı esame üyeliği üzerinden
  üretilir; istemci ev/deplasman tarafını tahmin etmez.

## Yerel kanıt

- `python tools/check_migrations.py supabase/migrations/0132_swan_identity_experience.sql`
- `flutter test packages/swansport_data/test/feature_flag_sync_test.dart packages/swansport_data/test/swan_experience_test.dart`
- `flutter test apps/swansport_app/test/navigation_test.dart apps/swansport_app/test/merged_routes_test.dart`
- İlgili Dart kaynaklarında `dart analyze`

Bu depoda Docker ve Supabase CLI bulunmadığından migration gerçek PostgreSQL
üzerinde uygulanmadı. Flutter analiz/testleri SQL fonksiyonlarının çalışma zamanı
davranışını kanıtlamaz. Canlıya geçmeden önce yerel Test Merkezi ile sahip,
yabancı kullanıcı, veli, aktif/pasif kulüp görevlisi, çocuk ve yetişkin
senaryoları; Storage politikaları; süre dolmuş/iptal QR; gerçek cihaz video
oynatma ve Android/Web üretim derlemeleri ayrıca kabul edilmelidir.

## Bilinen ilk sürüm sınırı

Video servis sözleşmesi MP4/MOV, 60 saniye ve 100 MB sınırlarını hem rezervasyon
RPC'sinde hem metadata alanlarında uygular. Mobil yükleme düğmesi, dosyanın gerçek
süresini güvenilir şekilde okuyacak platform bileşeni eklenene kadar açılmaz;
yalnız mevcut yayımlanmış videolar gösterilir. Bu karar yanlış süre bilgisini
istemciden kabul eden bir akışı üretime taşımamak içindir.
