# Çok branşlı antrenman motoru — 0120 yerel doğrulama

Tarih: 2026-10-16. Canlı SQL, deploy, commit veya push yapılmadı.

## Uygulanan kapsam

- Saf motorda yedi arketip, üç yeni immutable metrik tipi ve 60 branşın
  terminoloji/hazır dril/mesafe sözlüğü bulunur. Veri paketine bağımlılık yoktur.
  Katalog eşliği testte kaynaklar karşılaştırılarak denetlenir.
- 0120 mevcut doğrulayıcıları aynı imzayla genişletir. Yarım kg, RPE,
  tam sayı ve sonlu sayı sınırları korunur. Net puan -100..200 olabilir;
  hesap tutarlılığı için mevcut oran sözleşmesindeki 1e-6 toleransı kullanılır.
  Zihinsel çalışmada sıfır deneme sıfır orandır, kimlik/başarı kanıtı değildir.
- 120 deterministik, yeniden uygulanabilir platform şablonu vardır.
  Eski şablonlar ve kayıtlar değiştirilmez. Şablonlar resmi müsabaka
  kuralı veya tüm alt disiplinlerin resmî puanlama sistemi değildir.
- Mevcut genel aşama motoru kullanılır; açık faz atlamaları da yeni üç
  arketip için sınırlıdır. Yapılandırılmış bir set bir sonuç sayılır.
  Kilogram, net jüri puanı veya doğruluk eski hedef toplamına katılmaz.
- Tescil tablosu istemciye kapalı kaldığından `my_training_club_sports(uuid)`
  yalnız aktif kulüpte aktif üyeliği olan oturuma branş kodlarını projekte eder.
  Muhasebecilik tek başına erişim sağlamaz; özel tescil satırları açılmaz.
- Kişisel bağlam yalnız kendi onaylı/geçerli belgelerini, aktif üyeliklerini,
  kendi aktif sporcu bağlantısını, aktif sezon takım bağlantılarını ve kendi
  antrenman geçmişini okur. Takımlar tablosunda aktif/pasif alanı yoktur;
  kulüp bağlamında mevcut takımlar kullanılır, sahte sütun eklenmez.
- Filtre hesap/kulüp değişiminde sıfırlanır. Tek branş otomatik seçilir;
  çoklu branşlarda haplar, beş ve üzeri/boş bağlamda 60 branş araması vardır.
  Açık Tümü seçimi otomatik seçimden ayrıdır. Katalog seçimi yetki vermez.
  Eski İngilizce kodlar filtrede kanonik kodlarla eşleşir.
- Yeni pedlerde tipli kayıt, hata/tekrar deneme ve RAM taslağı; tur pedinde
  mesafe kısayolları ve isteğe bağlı frekans alanı vardır. Controller'lar
  dispose edilir; set/hesap değişimi pedleri yeniden kurar. Taslaklar kalıcı
  çevrimdışı kuyruk değildir. Beş alt sekme ve rotalar korunmuştur.

## Çalıştırılan kontroller

- `node tools/training_archetypes_sql_test.mjs`: 23/23 PostgreSQL fixture
  senaryosu; eski dört arketip, yeni üç arketipin gerçek RPC kayıt/düzeltme
  ve audit yolu, faz atlama, sınırlar, 120 şablon ve dar RPC yetkisi.
- `python tools/check_migrations.py`: 120 migration, sıfır sorunlu dosya.
- `python tools/check_faq.py`: 44/44 özellik yardımı mevcut.
- `python tools/check_push_routes.py`: 42 eşleme, kayıp yok.
- `python tools/check_mobile_ui_tokens.py --syntax`: 601 Dart dosyası,
  sıfır söz dizimi hatası; 24/24 mobil kaynak sözleşmesi.
- `node tools/sports_federations_catalog_test.mjs`: 3/3.
- `git diff --check`: temiz.

## Kabul sınırı / sonraki doğrulama

Bu ortamda Flutter/Dart SDK yoktur. Saf motor, veri bağlamı ve widget
regresyon testleri eklenmiştir fakat çalıştırılmamıştır. Söz dizimi taraması
typecheck değildir. Flutter analyze, format, VM/widget testleri ve gerçek
cihazda dar ekran/klavye/büyük metin UAT'si henüz kabul edilmiş sayılmaz.
SQL fixture azaltılmış yerel PostgreSQL şemasıdır; tam üretim zinciri veya
gerçek Supabase Auth/RLS/cihaz uçtan uca kanıtı değildir.

SDK bulunan ortamda motor testlerini, veri paketinin `sport_context_test.dart`
ve `training_cockpit_test.dart` testlerini, mobilde `training_cockpit_test.dart`,
`smart_sport_scope_test.dart` ve `navigation_test.dart` testlerini çalıştır.
Üretim kullanımı öncesi 0119/0120 migration sırası ayrıca doğrulanmalıdır.
