# Sezon açılışı — ilk sürüm

2026-10-07. Yerel uygulama ve migration hazır; canlı veritabanına uygulanmadı.

## Kullanım

Profil → Yönetim → Sezon Açılışı. Kulüp yöneticisi, aktif kulüp ve
`season_setup` bayrağı gerekir. Bayrak ilk kurulumda `admins` seviyesindedir;
bu kademede platform yöneticiliği de bulunan kulüp yöneticisi deneyebilir.

Beş adım: sezon tarihleri, yeni takım ve mevcut kadro, isteğe bağlı ilk haftaların
programı, isteğe bağlı aidat taslağı, son kontrol. Mevcut takımı başka sezona
taşıma bu sürümde yoktur. Hesabı olmayan sporcular kadrodan dışlanmaz.

Aidat taslağı pasiftir. **Aidat Yönetimi → Planlar** bölümünden etkinleştirilir;
atama ve tahakkuk ayrıca yapılır. Yeni etkinleştirme kontrolü mevcut
`FinanceService.setPlanActive` yöntemini kullanır. Pasif planlar yeni atama
listesinde görünmez; eski atamalar kaldırılabilir. Mevcut burslar değiştirilmez.

## Kaydetme ve tekrar deneme

`open_club_season` bütün kayıtları tek PostgreSQL işlemi içinde oluşturur.
Yetki, kulüp, bayrak, tarih, kadro, program ve tutar sunucuda doğrulanır.
Yeni etkinlikler mevcut 0080 `create_event_series` fonksiyonunu kullanır.
Kulüp satırı kilidi aynı kulübün hazırlıklarını sıraya koyar. Sunucudaki
`season_setup_runs` aynı aktör/işlem kimliğini aynı sonuca bağlar; farklı içerik
aynı kimlikle kabul edilmez. Kayıt tablosunun istemciye doğrudan erişimi yoktur.

Yanıt kaybolursa ekran hazırlığı değiştirmez; aynı kimlikle tekrar dener.
Kesin doğrulama/yetki reddi formun düzeltilmesine izin verir. Belirsiz sonuçtan
çıkmak isteyen kişi açıklamayı kabul edip Takımlar'a gider; önce oluşmuş kayıtları
kontrol eder. Hazırlık cihazda kalıcı saklanmaz: uygulama kapanırsa önce kayıtlar
kontrol edilmelidir. Sunucuda aynı sezon/takım adının tekrar oluşturulması da
engellenir. Aktif kulüp değişirse önceki kadroyla gönderim kapatılır.

## Doğrulama

- Gerçek 0087 ve mevcut 0080 seri fonksiyonu PGlite üzerinde çalıştırıldı.
  Sekiz SQL senaryosu: hesapsız sporcu, Türkiye saati, pasif plan, tekrar deneme,
  izinler/bayrak, geçersiz kadro/program/tutar, alt işlem hatasında geri alma,
  opsiyonel adımlar, ad çakışması ve idempotent migration.
- Dart sözleşme/servis testleri: tarih/gün/adet/tutar sınırları, RPC parametreleri,
  geçersiz isteğin gönderilmemesi ve gerçek sunucu yanıtının ayrıştırılması.
- Widget testleri: rol/bayrak kapısı, beş adım, 360px ekran, belirsiz/kesin hata,
  aynı kimlikle tekrar, çift gönderim, kulüp değişimi, program/aidat seçenekleri,
  plan durumunun sunucu yanıtını beklemesi ve hata geri bildirimi.
- SSS ve bayrak eşleşmesi, gezinme bütünlüğü, tanılama kataloğu ve SQL sözdizimi
  kontrolleri test akışına dahildir.

Son tam koşu: **250 uygulama ve 288 veri testi** geçti. Ardından eklenen
belirsiz sonuçtan çıkış senaryosuyla sekiz sezon widget testi tekrar geçti;
aidat durum kontrolünün üç testi tam uygulama koşusuna dahildir. Sekiz SQL
senaryosu, 87 migration parse kontrolü, 36/36 SSS, 37 bildirim rotası ve
üretim web derlemesi başarılı. Yeni kaynak analizi temiz; entegrasyonda
hata/uyarı yok, mevcut kaynaklardaki biçim önerileri kapsam dışında kaldı.

PGlite tek bağlantılıdır; iki PostgreSQL oturumuyla yarış testi ve gerçek hesapla
bildirim/Android UAT ayrıca gerekir. Widget testleri görsel cihaz UAT'nin yerine geçmez.

## Canlıya geçiş

Bekleyen migration'lar sırayla, dosya başına işlem içinde uygulanmalı; 0087,
0080'in takım parametreli seri fonksiyonuna ihtiyaç duyar. Kilit zaman aşımı
15 saniyedir. Ardından seçili kulüp yöneticisi hesabıyla tüm akış ve bildirimler
denenir. Bayrak yalnız bu doğrulamadan sonra `testers`, ardından `everyone`
yapılır. Aynı migration'daki aktif SSS kaydı yayın kapısını karşılar.

Bu çalışma canlı migration, bayrak değişikliği veya dağıtım yapmadı.
