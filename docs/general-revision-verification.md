# Genel revizyon ve piksel standardı — 0121

2026-10-16. Yerel kaynak uygulaması; canlı SQL/deploy/commit/push yapılmadı.

## Kapsam

- Eski 0001–0120 migration dosyaları ve mevcut bağımsız SQL testleri değiştirilmedi.
  Tüm yeni veritabanı davranışı 0121 içindedir.
- Plandaki 11 bayrak yalnız mevcut kademe `admins` ise `everyone` olur.
  Bilerek kapatılmış/testers durumundaki bayraklar ve diğer özellikler korunur.
  SSS yayın tetikleyicisi korunur; eksik aktif yardım bütün işlemi geri alır.
  Bu migration'ın hazırlanması canlıdaki bayrakları değiştirmez.
- `club_training_sports` resmi tescilden ayrıdır. Yazma yalnız aktif kulüpteki
  aktif `club_admin`/`coach` üyeliğinin dar RPC'sinden geçer. Plandaki `admin`
  gerçek enum değildir; gerçek temel şemayla test edilerek düzeltildi.
  Club satır kilidi eşzamanlı liste değiştirmelerini sıralar. Eski satırların
  oluşturma metaverisi korunur; null/boş liste temizler; geçersiz kodlar elenir;
  60 geçerli branş sınırı atomiktir. Muhasebecilik yazma yetkisi vermez.
- Okuma aktif üyelere branş kodları düzeyindedir; resmi tescil tablosu istemciye
  açılmadı. Birleşik bağlam ana branş, resmi tescil, takım ve seçilen antrenman
  branşlarını kapsar. Seçim lisans/federasyon yetkisi üretmez.
- Ortak servis başarıdan sonra bağlamı yeniler; widget Supabase çağırmaz.
  Kulüp Ayarları'ndaki aramalı 60 branş sheet'i başarısız kayıtta seçimi korur,
  çift gönderimi ve kayıt sırasında kapanmayı engeller; controller dispose edilir.
  Sheet başlangıçta birleşik branşları işaretler. Ana/tescil/takım branşlarının
  filtrelerde ayrıca kalacağı hem sheet'te hem SSS'de açıkça belirtilir.
- Plandaki on modül + Kulüp Ayarları ortak `swanModuleAppBar` kullanır.
  Altyapı isteğe bağlı saat/tesis alt başlığını destekler. Bu kapsamda ham
  AppBar/ListTile ve SwanColors.textSecondary kalmadığı source testiyle korunur.
  Ana akış/profilin özgün başlıkları ve konsol değiştirilmedi.
- Ortak yüzey/aksiyon/bilgi kartları, gruplu ayarlar, belge metaverisi,
  antrenman formu ve tesis kısayolları tema duyarlıdır. Palette var olmayan
  `borderSubtle`/`inkSoft` yerine `line`/`inkMuted` kullanıldı. Material renk
  yüzeyinin sahibidir; dokunma dalgası opak bir Container altında gizlenmez.
- Belge/iş akışı test anahtarları, 'Bekleme listem', 'Saha görevlerim',
  'Görev devret', eski rotalar ve beş alt sekme korunmuştur.

## Doğrulama

- Yeni PostgreSQL fixture testi: 4/4; gerçek temel enum/RLS ve gerçek 0070
  yardım kapısı, izinler, tekrar uygulama, sınır ve geri alma senaryoları.
- Yeni source/senkronizasyon testi: 5/5; 11 modül sözleşmesi, anahtarlar,
  servis/UI bağlantısı ve SQL/Dart özellik anahtarı eşliği.
- Planda `multi_branch_training_sql_test.mjs` adıyla geçen dosya depoda yoktur;
  0120'nin mevcut testi `training_archetypes_sql_test.mjs` içindedir ve tam koşuya dahildir.
- Katalog testi: 3/3. SSS: 44/44. Push: 42 eşleme, kayıp yok.
- Migration söz dizimi: 121 dosya, sıfır sorun.
- Mobil kontrol: 605 Dart dosyası sıfır syntax hatası, 24/24 kaynak sözleşmesi.
- Tam `node --test --test-concurrency=2 tools/*_test.mjs`: **861/861 geçti**,
  sıfır başarısız/atlanmış test, çıkış 0 (yaklaşık 13 dakika). Bu sayı
  bağımlı dosyalardan importla yeniden koşan senaryoları içerir; 861 benzersiz
  SQL senaryosu değildir. Hakem, canlı skor, lig, takip, antrenman, mali,
  kimlik, gizlilik ve diğer mevcut SQL/JS dosyalarının tamamı kapsanır.
  Yeni SQL dosyası son fixture güçlendirmeleriyle ayrıca 4/4 tekrar geçti;
  koşu başladıktan sonra eklenen source/senkronizasyon dosyası ayrıca 5/5 geçti.
- `git diff --check` ve stage edilmiş diff kontrolü temiz.

## Kabul sınırı

Flutter/Dart SDK bu ortamda yok. Eklenen üç widget ve iki veri servis testi
henüz çalıştırılmadı; `flutter analyze`, gerçek widget/navigation testleri,
web/APK derlemesi ve piksel ekran görüntüsü kabulü yapılmış sayılmaz. Syntax
taraması typecheck değildir. SDK bulunan ortamda `general_revision_ui_test.dart`,
`club_training_sports_test.dart`, mevcut sezon/yoklama/belge/iş akışı/gezinme
regresyonları ve açık/koyu 320px büyük metin + klavye UAT'si çalıştırılmalıdır.
SQL testleri yerel azaltılmış fixture'dır, üretim Auth/cihaz kabulü değildir.
