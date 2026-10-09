# Hata ve kullanım merkezi

2026-10-07 — yerel uygulama ve doğrulama. Canlı migration veya yayın yapılmadı.

## Kullanım

- Mobil/web uygulama: Profil → Gizlilik ve Hesap → Uygulamayı iyileştirmeye yardım et.
  Hata tanılaması ve kullanım/performans ölçümü ayrı tercihlerdir; varsayılanları kapalıdır.
- Destek → Sorun bildir: konu ve açıklama zorunludur. Teknik bilgi kutusu varsayılan kapalıdır.
  Bu kutu yalnızca o talebe bilgi ekler; otomatik kayıt tercihini değiştirmez.
  PNG/JPEG görsel seçilebilir, önizlenebilir ve gönderilmeden kaldırılabilir.
- Konsol → Platform → Hata ve Kullanım (`/hata-merkezi`): yalnızca platform yöneticisi.
  Sürüm, platform, ekran ve durumla filtreleme; sunucuda 50 satırlık sayfalama;
  kaynak konumu, son teknik işlemler ve ilişkili sunucu izleri; inceleme/çözüm işaretleme.
  Yeni olay çözüm zamanından sonra gerçekleşmişse durum otomatik “Yeniden oluştu” olur.
  Geç gönderilen eski olay çözülmüş hatayı yeniden açmaz. Gruplama ekran/işlem/kod ve varsa kaynak konumunu içerir; kaynak yığını olmayan farklı ekran hataları birleştirilmez.
- Konsol destek kuyruğunda, kullanıcı eklemişse teknik bilgi ve özel görsel açılır.

## Toplanan bilgi ve izinler

Kayıtlar yalnızca denetlenmiş kod tanımlayıcılarından yeniden oluşturulur:
ekran rotası, işlem adı, standart hata kodu, uygulama/sürüm/platform, süre, zaman,
rastgele oturum/işlem/olay UUID'leri ve bilinen paket dosyasının satırı.
İstemcide ve SQL'de ayrı beyaz listeler vardır. `tools/generate_diagnostics_catalog.py`
bu listeleri kaynak rotalar, migration'lardaki RPC/tablo adları ve paket dosyalarından üretir;
`--check` ayrışmayı yakalar.

İstisnanın metni, HTTP gövdesi/başlıkları, URL sorgusu/parametreleri, e-posta/ad,
mesaj, form alanı, belge, sağlık verisi, para tutarı veya finansal kayıt kimliği
otomatik teknik olaylara kopyalanmaz. Bilinmeyen rotalar `/unknown`, işlemler `unknown` olur.
Kaynak konumları en fazla 10, son teknik işlemler en fazla 30'dur.

Hata izni açıkken önceki teknik işlemler cihaz belleğinde tutulur ve ancak hata veya
açıkça seçilmiş destek ekiyle gönderilir. Kullanım izni açıkken ekran/işlem sonuçları ve
süreleri düzenli gönderilir. Hata izni kapalıysa kullanım olaylarına kaynak yığını eklenmez.
Tercihler cihazda saklanır; arka planda yüklenmeleri ilk ekranı geciktirmez.
Hızlı tercih değişiklikleri sırayla yazılır. Kapatmak bekleyen olayları ve yerel izleri temizler;
daha önce gönderilmiş kayıtları geri almaz. Devam etmekte olan ağ isteği geri çağrılamaz.

Gönderim giriş yapmış kullanıcı gerektirir. Hesap değişince/çıkışta oturum ve bekleyen
izler temizlenir; 30 dakikalık hareketsizlikten sonra yeni oturum açılır.
Oturum-sahip eşlemesi özel tabloda kalır; genel konsol hata ayrıntısı kullanıcı kimliği dönmez.
Destek talebi zaten yazarıyla bağlantılıdır ve teknik eki yalnızca yazar/yetkili platform
yöneticisi okuyabilir. Muhasebeciye yeni sportif veya kişi verisi erişimi verilmez.

## Gerçek kapsama

- Flutter framework hataları, platform tarafından bildirilen yakalanmamış Dart hataları
  ve Riverpod sağlayıcı hataları. Mevcut hata gösterimi/handler'lar korunur.
- Supabase istemcisinin REST/RPC/auth/storage HTTP istekleri: başlama, tamamlanma,
  HTTP hata sınıfı, ağ/yanıt akışı hatası ve gövde bitimine kadar süre. Yanıt gövdesi okunup
  tanılama verisine eklenmez; uygulamaya aynı akış iletilir. Yarıda kesilen yanıt başarı sayılmaz.
- Uygulama sayfa açılışları ve ilk çizime kadar süre; konsolda rota değişimleri.
  Mobilde 32 ms üzerinde çerçeve örneği en çok 10 saniyede bir alınır.
- Mali düzeltme oluşturma, tesis rezervasyonu, destek talebi ve bildirimden açılma
  akışlarında ayrı işlem izleri. Her düğmeye genel dokunma kaydı eklenmedi.
- HTTP izleri standart `x-client-info` başlığına rastgele `swan-trace` kodu ekler.
  Mevcut gider denetimi, mali dönem, yoklama operasyonu ve destek yazma tetikleyicileri
  yalnızca bu kodu, işlem adını ve zamanı kaydeder. Satır içeriğini kopyalamaz;
  tanılama tetikleyicisinin hatası iş kaydını bozamaz. İşlemin geri alınması sunucu izini de geri alır.
- Mali tutarlılık kontrolü, 0085'teki **mevcut** `finance_adjustment_entry_matches`
  doğrulayıcısını kullanır. Geçersiz tutarlı ve onaylı fakat gerçek defter hareketi eşleşmeyen
  ters kayıtları yalnızca adet olarak gösterir. Bu kontrol izinli telemetri örneğine bağlı değildir;
  başka alanlardaki tüm sessiz hataları tespit ettiği iddia edilmez.

15 dakikalık pencerede aynı hatanın en az 3 tekrarı, en az 10 sonuç içinde ≥%20 başarısızlık
veya en az 5 yavaş işlem konsol uyarısı üretir. Ağda yavaş işlem eşiği 3 saniyedir.
Başarısızlık oranı ve işlem istatistiğinin paydası yalnızca kullanım ölçümü açık olaylardan
hesaplanır; yalnız hata gönderen kişiler oranı yapay olarak yükseltmez.
Uyarılar konsolda gösterilir; e-posta, push veya üçüncü taraf bildirim kurulmadı.
Konsol verisi Yenile ile güncellenir; cron uyarıları ayrıca 15 dakikada bir hesaplar.

## Gönderim ve saklama

Bellek kuyruğu en fazla 100 olaydır; kalıcı çevrimdışı kuyruk yoktur.
Gönderim en fazla 20 olay ve 60 KB paketlerle yapılır. Sunucu sınırı 64 KB ve kullanıcı
başına saatte 1000 olaydır; aynı olay UUID'sinin tekrar gönderimi sayacı çoğaltmaz.
Kullanıcı eylemi tanılama gönderimini beklemez. Gönderim 8 saniyede zaman aşımına düşer;
başarısız gönderimler 15–300 saniyelik beklemeyle tekrar denenir. Tanılama istekleri
kendileri izlenmez. Gönderilmemiş veriler uygulama kapanırsa kaybolabilir.

Teknik olaylar, sunucu izleri, oturumlar, uyarılar ve teknik destek eki metaverisi
30 günlük süreyle günlük temizlenir. Hata gruplarının kişisel veri içermeyen özetleri
90 gün sessiz kaldıktan sonra silinir. Ham olayları kalmayan gruplar açık hata sayısına girmez.
Günlük iş nedeniyle fiziksel silme zamanında bir günlük gecikme olabilir.
Normal destek yazışmasının saklama süresi bu tanılama temizliğinden ayrıdır.

Görsel istemcide yeniden PNG kodlanır; EXIF/konum metaverisi taşınmaz, iki boyut da en fazla
1600 piksel ve dosya en fazla 5 MB olur. Otomatik ekran görüntüsü/oturum videosu alınmaz.
Özel `diagnostic-attachments` deposuna yalnız kendi talebinin yoluyla yüklenebilir.
İmzalı okuma bağlantısı 5 dakika geçerlidir. 30 günden eski nesne için yeni okuma izni
verilmez; önceden üretilmiş bağlantı kendi kısa süresi dolana kadar çalışabilir.

**Depodaki fiziksel dosya SQL ile silinmez.** `tools/purge_diagnostic_attachments.mjs`
Storage API üzerinden sildikten sonra referansı onaylar. Silme başarısızsa referans tekrar
denemek için korunur. Bu araç aynı depodaki sahipsiz/eski yüklemeleri de temizler.
Servis anahtarı yalnız sunucu bakım işindedir; Flutter'a veya loglara yazılmaz.

## Etkinleştirme

1. 0085 dahil önceki migration'ların uygulanmış olduğunu doğrula.
2. `supabase/migrations/0086_diagnostics_center.sql` dosyasını tek işlemde uygula.
   `lock_timeout=15s` korunur. Kilit zaman aşımında yalnız bu dosyayı tekrar çalıştır.
3. `pg_cron` mevcutsa migration iki isimli işi kurar: 15 dakikalık uyarı ve günlük
   `03:23` metaveri temizliği. Kurulumda `cron.job` kayıtlarını doğrula.
   Cron mevcut değilse aynı fonksiyonları yetkili sunucu bakım işiyle planla;
   istemci/anon bu özel fonksiyonları çalıştıramaz.
4. `.github/workflows/diagnostic-retention.yml` günlük `03:41 UTC` fiziksel görsel temizliğini
   çalıştırır. GitHub Actions'ın etkin ve `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
   repository secrets değerlerinin tanımlı olması gerekir. Manuel çalıştırma da vardır.
   Bunlar **bu görevde tanımlanmadı/çalıştırılmadı**. Temizlik başarısızlığı Actions'ta görünür.
5. Yeni uygulama/konsol paketlerini normal yayın sürecinden geçir. Konsol sürümü
   `--dart-define=APP_VERSION=<konsol sürümü>` ile verilebilir; varsayılan `0.1.0`.
   Mobil sürüm PackageInfo'dan gelir. Yayınlar ayırt edilsin diye sürüm/build artırılmalıdır.
6. Gerçek hesaplarla kullanıcı izni → bir başarısız işlem → konsoldaki hata → çözüm →
   yeniden oluşma ve teknik ekli destek talebi akışını dene. Başka hesapla ek/oturum erişimini
   reddettiğini ve günlük temizliğin gerçekten çalıştığını doğrula.

## Doğrulama ve sınırlar

- Uygulama tam test turu: **240 geçti**. Testlerin fixture/açılış beklentisi için
  `--dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=` kullanılır;
  projedeki varsayılan backend tanımlarıyla “eksik yapılandırma” testi geçerli değildir.
- Ortak veri paketi **281**, konsol **43** test: tamamı geçti. Uygulamayla toplam **564 Flutter testi**.
  Yeni çekirdek testleri izin/mahremiyet, kuyruk/batch, hesap ayrımı, tekrar gönderim,
  ağ akışı hatası, ortak işlem izi ve hızlı/geç yüklenen tercihleri kapsar.
- `node --test tools/diagnostics_sql_test.mjs`: gerçek 0086 fonksiyonları ve gerçek
  0085 defter doğrulayıcısıyla **10 senaryo**. Kurulum tekrarı, izinler, ayıklama,
  sınırlar, yeniden açılma, filtre/sayfalama, oran/uyarı, sunucu izi, destek/Storage
  politikası, saklama ve sessiz mali hata sayaçları. PGlite tek bağlantılıdır;
  canlı Supabase/pg_cron ve iki oturumlu eşzamanlılık UAT'sinin yerine geçmez.
- `node --test tools/diagnostic_retention_test.mjs`: **4 senaryo**, gerçek bakım aracı ve
  sahte Storage yanıtıyla silme/onay sırası, hatada referans koruma, yol ve sır güvenliği.
- Yeni kaynaklar ve entegrasyonların analizi: 0 hata/uyarı. Yeni çekirdek kaynaklarda lint temizliği yapıldı.
- Mobil/web uygulama ve konsol `main_production.dart` üretim web derlemeleri başarılı.
  Flutter araç çıktısındaki Cupertino font ailesi uyarısı derlemeyi durdurmadı;
  depodaki kaynaklarda CupertinoIcons kullanımı bulunmadı. Canlı görsel UAT yapılmadı.
- Katalog eşleşmesi, 0086 SQL söz dizimi, 35/35 SSS kapısı ve diff kontrolü başarılı.

Native işletim sistemi çökmesi/uygulamanın zorla öldürülmesi, ayrı isolate hataları,
giriş öncesi sunucuya gönderim ve her kullanıcı eyleminin videosu kapsamda değildir.
Üretim web derlemesinde küçültülmüş kaynak yığınları Dart dosyası/satırı vermeyebilir;
bu durumda ekran/işlem/HTTP kodu/iz ile inceleme yapılır. Kaynak haritası servisi kurulmadı.
Canlı hesapla görsel UAT, fiziksel Android/iOS cihaz testi ve gerçek Storage API entegrasyonu
bu görevde yapılmadı. Yeni özellik yerelde hazırdır; canlıda aktif olduğu iddia edilmez.


## 0089 — düzeltme doğrulaması (yerel, yayınlanmadı)

Sürümsüz “Düzeltildi” durum değişikliği ileri migration ile kapatıldı. Artık
sürüm/platform bildirimi, kapsamlı teknik tekrar ve destek sahibinin teyidi vardır.
Kurulumda 0086'dan sonra 0089 ve her iki yeni uygulama paketi gerekir; canlıya bu
görevde uygulanmadı. Güncel sözleşme: `docs/diagnostic-fix-verification.md`.
