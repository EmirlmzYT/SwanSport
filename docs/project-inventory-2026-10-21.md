# SwanSport — eksikler, doğrulamalar ve geliştirme envanteri

Tarih: **21 Ekim 2026 (Europe/Istanbul)**. Kapsam: mobil/web uygulaması, konsol, ortak veri katmanı, branş motoru, migrationlar, yerel araçlar, yayın hattı ve işletim belgeleri.

**31 alanda 300 madde:** 23 doğrulanmış durum/uyuşmazlık (S), 47 raporda açık bırakılmış kapsam (R), 106 doğrulama ihtiyacı (D), 124 isteğe bağlı geliştirme önerisi (G).

Bu liste, incelenen kaynak ve belgeler üzerinden hazırlanmış kapsamlı bir iş envanteridir; henüz gözlenmemiş bütün hataların bulunmuş olduğu iddiası değildir. Canlı şema, gerçek kullanıcı hesabı, fiziksel cihaz, mağaza hesabı ve ödeme sağlayıcısı bu incelemede denetlenmedi. **D maddesi güvenlik açığının var olduğunu, G maddesi işlevin kesinlikle bulunmadığını göstermez.** G mevcut işlevin genişletmesini de kapsar. R tarihli rapora dayanır; uygulamadan önce güncel kaynak ve ortamla karşılaştırılmalıdır.

## İşaretler ve bitiş ölçütleri

| Tür | Anlam | Nasıl kapanır? |
| --- | --- | --- |
| S | Güncel kaynak/test/araçla doğrulanan eksik, bakım borcu veya uyuşmazlık | Doğru ürün/yetki davranışı belirlenir; kaynak ve test birlikte düzeltilir; ilgili kontrol geçer. Başarısız test tek başına üretim hatası kanıtı değildir. |
| R | Raporda açık bırakılmış iş veya kapsam sınırı | Güncel durum doğrulanır; ihtiyaç sürüyorsa mevcut akış genişletilir ve davranışla kabul edilir. |
| D | Canlı/cihaz/güvenlik/işletim kanıtı gereken kontrol | Sürüm, adımlar, beklenen ve gerçek sonuç kaydedilir. Geçerse yeni özellik yazılmadan kanıtla kapanır. |
| G | Ürün veya teknik geliştirme önerisi | İhtiyaç ve kapsam seçilir; mevcut akış genişletilir; gerçek veride fayda ve yetki davranışı kabul edilir. |

| Öncelik | Anlam |
| --- | --- |
| P0 — 70 madde | İlgili özellik/dağıtım kanalı açılmadan çözülmeli veya doğrulanmalı. Kapalı kalacak bir modül bütün ürünü zorunlu bloke etmez. |
| P1 — 98 madde | Kapalı beta ve güvenilir işletim için yüksek öncelik. |
| P2 — 122 madde | Günlük kullanım, ölçek ve kalite iyileştirmesi. |
| P3 — 10 madde | İhtiyaç/maliyet doğrulanınca seçilecek ileri kapsam. |

Öncelikler öneridir; 300 madde aynı anda uygulanacak taahhüt değildir. Aynı testin tema/boyut varyasyonları sayıyı şişirmeden gruplanmıştır. Modül kontrolleriyle bütünleşik zincir kontrolleri farklı kabul düzeyleridir.

## Güncel doğrulama sonuçları

| Kontrol | Sonuç | Sınır |
| --- | --- | --- |
| Ortak veri tam Flutter koşusu | **511 geçti, 0 başarısız** | Canlı RLS/PostgREST ve cihaz kanıtı değildir. |
| Mobil tam Flutter koşusu | **599 geçti, 13 başarısız** | Beş test dosyası; test/kod uyumsuzluğu çözülmeli. |
| Konsol tam Flutter koşusu | **81 geçti, 3 başarısız** | Bu görüşmenin önceki genel inceleme adımında çalıştırıldı. |
| Migration söz dizimi | **139 SQL dosyası, 0 sorun** | Parse sonucu gerçek Supabase'de zincir kurulumu kanıtı değildir. |
| SSS sözleşmesi | **46 bayrak / 45 eşleşme** | federation_bulletin açığı; içerik veya denetleyici nedeni araştırılmalı. |
| Bildirim rotaları | **42 eşleme, kayıp yok** | Mevcut eşlemelerin korunması; tüm türler/gerçek teslim kabulü değildir. |
| Mobil UI sözleşmesi | **24/24 kaynak tarandı, 8 bulgu** | Statik token/metin kontrolü; görsel cihaz kabulü değildir. |
| Kod grafiği | 7 Ekim indeksinde değişmiş/eksik kapsamlar | Maddi bulgular güncel kaynak ve çalışan kontrollerle karşılaştırıldı; indeksten yokluk sonucu çıkarılmadı. |

Çalıştırılan komutlar:
- Veri: `flutter test --no-pub --reporter expanded` (packages/swansport_data).
- Mobil: `flutter test --no-pub --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY= --reporter expanded` (apps/swansport_app).
- Konsol: `flutter test --no-pub --reporter expanded` (apps/swansport_console).
- Python: `tools/check_faq.py`, `tools/check_push_routes.py`, `tools/check_migrations.py`, `tools/check_mobile_ui_tokens.py`.

Tam mobil/veri günlükleri Git dışındaki `build/project-inventory-mobile-tests.log` ve `build/project-inventory-data-tests.log` dosyalarında. Sonuç özeti bu kalıcı belgede korunur. Bu incelemede genel analyze, APK/IPA/web build, bütün SQL davranış paketleri ve fiziksel cihaz kabulü tekrar çalıştırılmadı.

13 mobil başarısızlığın dağılımı:
- explore_layout_test: 1 (duyuru başlığı).
- mobile_ui_cleanup_test: 5 (ham jetonlar ve dört tema/sayı rozet varyasyonu).
- mobile_glass_chrome_test: 1 (header blur beklentisi).
- reference_header_test: 6 (dört tema/boyut hedefi, misafir oluşturma kapısı, kaydırma yüzeyi).

3 konsol başarısızlığı:
- federation_results_screen_test: admin geçişi/görev şartı.
- module_visibility_test: federasyon/pazaryeri görünürlük beklentisi.
- mission_control_test: Denetim & Sistem sekmesinin ekran dışında kalması ve bekleme kaydının bulunamaması.

## Zaten bulunan temeller — yeniden eksik diye yazılmadı

- Kalıcı çevrimdışı yoklama kuyruğu var; cihaz/iki oturum kabulü ve yayın kademesi ayrı iştir.
- SSS düzenleme ekranı var; 46/45 eşleştirme bulgusu ayrı iştir.
- Android yayın imzası ve önceki paketle sertifika eşliği var; yeni keystore oluşturmak mevcut eksik değildir.
- Hesap silme, şikâyet ve engelleme kodları var; gerçek kabul ve Storage yaşam döngüsü ayrı iştir.
- Transfer talebi 0138 ile yerelde var; eski 0114 “yok” notu güncel eksik değildir.
- Kısmi zimmet iadesi 0137 ile yerelde var; eski tam-iade sınırı güncel yokluk değildir.
- Tesis rezervasyon/çakışma altyapısı 0108 ile var; canlı zincir/yarış kabulü ayrıca gerekir.
- Gerçek birleşik takvim ve tek seferlik ICS aktarımı var. Ayrı fixture controller, üretim takviminin sahte veri kullandığını göstermez.
- Beslenme ve kişisel ekipman için sonraki kaynaklar var; eski prototip raporundan güncel yokluk çıkarılmaz.
- Apple imzalama/TestFlight hattı hazırlanmış; imzalı gerçek dağıtımın kanıtı ayrı iştir.
- Son açık belgelenen canlı kurulum 0107'ye ilerlemiş. Eski 0104 kaydı güncel son durum diye kullanılmaz; bugünkü canlı durum yine doğrulanmalıdır.

## Alan dizini

| Alan | Madde aralığı | Adet |
| --- | --- | ---: |
| 1. Güncel kontrollerde doğrulanan sorunlar | SW-001–SW-010 | 10 |
| 2. Tam mobil test koşusundaki ek uyuşmazlıklar | SW-011–SW-015 | 5 |
| 3. CI ve yayın kalitesi | SW-016–SW-025 | 10 |
| 4. Canlı sürüm ve migration eşliği | SW-026–SW-035 | 10 |
| 5. Apple, iOS ve TestFlight | SW-036–SW-045 | 10 |
| 6. Mağaza hazırlığı ve Android dağıtımı | SW-046–SW-055 | 10 |
| 7. Hesap, telefon ve kimlik doğrulama | SW-056–SW-065 | 10 |
| 8. Veri gizliliği ve yetki kabulü | SW-066–SW-075 | 10 |
| 9. Sunucu işletimi ve geri kazanım | SW-076–SW-085 | 10 |
| 10. İlk kullanım ve ana sayfa | SW-086–SW-095 | 10 |
| 11. Kulüp, personel, kadro ve sezon | SW-096–SW-105 | 10 |
| 12. Takvim ve program | SW-106–SW-115 | 10 |
| 13. Yoklama ve çevrimdışı çalışma | SW-116–SW-125 | 10 |
| 14. Antrenman motoru ve antrenör işleri | SW-126–SW-135 | 10 |
| 15. Performans ve gelişim raporu | SW-136–SW-145 | 10 |
| 16. Sağlık, beslenme ve kişisel ekipman | SW-146–SW-155 | 10 |
| 17. Veli ve çocuk işlemleri | SW-156–SW-165 | 10 |
| 18. Duyurular ve kulüp iletişimi | SW-166–SW-175 | 10 |
| 19. Aidat, mali işler ve ödeme | SW-176–SW-185 | 10 |
| 20. Kulüp envanteri ve transfer | SW-186–SW-195 | 10 |
| 21. Tesis, rezervasyon ve partner | SW-196–SW-205 | 10 |
| 22. Sosyal akış ve mesajlaşma | SW-206–SW-215 | 10 |
| 23. Federasyon ve resmi işlemler | SW-216–SW-225 | 10 |
| 24. Hakem kokpiti ve spor protokolleri | SW-226–SW-235 | 10 |
| 25. Canlı skor ve lig tablosu | SW-236–SW-245 | 10 |
| 26. Bildirim motoru | SW-246–SW-255 | 10 |
| 27. Arayüz, erişilebilirlik ve cihaz performansı | SW-256–SW-265 | 10 |
| 28. Destek, tanılama ve bakım | SW-266–SW-275 | 10 |
| 29. Ticari model ve pazaryeri | SW-276–SW-285 | 10 |
| 30. Teknik borç, belgeler ve ürün ölçümü | SW-286–SW-295 | 10 |
| 31. Bütünleşik gerçek hesap kabul senaryoları | SW-296–SW-300 | 5 |

## Tam liste

### 1. Güncel kontrollerde doğrulanan sorunlar

Kanıt/bağlam: [apps/swansport_console/test/federation_results_screen_test.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/test/federation_results_screen_test.dart>) · [apps/swansport_console/test/module_visibility_test.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/test/module_visibility_test.dart>) · [apps/swansport_console/test/mission_control_test.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_console/test/mission_control_test.dart>) · [tools/check_faq.py](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/tools/check_faq.py>) · [tools/check_mobile_ui_tokens.py](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/tools/check_mobile_ui_tokens.py>).

- [ ] **SW-001 · S · P0** — Federasyon sonuç modülünde platform admin geçişi ile testin beklediği görev şartını uzlaştır; doğru yetki sözleşmesiyle testi geçir.
- [ ] **SW-002 · S · P0** — Konsol modül görünürlüğü testindeki federasyon/pazaryeri beklentisini güncel yayın ve SwanAccess sözleşmesiyle uzlaştır.
- [ ] **SW-003 · S · P1** — Mission Control testinde ekran dışında kalan Denetim & Sistem sekmesinin erişimini ve bekleme listesi görünümünü düzelt.
- [ ] **SW-004 · S · P1** — SSS denetimindeki federation_bulletin eşleştirme açığını araştır; 46 bayrağın tamamını yardım kaydıyla doğru eşleştir.
- [ ] **SW-005 · S · P2** — Profil ekranının statik kontrolde yakalanan doğrudan siyah/beyaz renklerini anlamlı tema jetonlarıyla uzlaştır.
- [ ] **SW-006 · S · P2** — Mesaj ekranındaki ham fontSize kullanımlarını mevcut tipografi basamaklarıyla uzlaştır.
- [ ] **SW-007 · S · P2** — Mesaj ekranındaki doğrudan hex renklerini mevcut palet ve gerekli marka istisnalarıyla uzlaştır.
- [ ] **SW-008 · S · P2** — Mesaj ekranındaki doğrudan siyah/beyaz renklerini açık/koyu tema sözleşmesiyle uzlaştır.
- [ ] **SW-009 · S · P2** — Sporcu çalışma alanındaki ham fontSize/TextStyle/siyah-beyaz kullanımlarını ortak jetonlarla uzlaştır.
- [ ] **SW-010 · S · P2** — Bildirim ekranı ile statik denetimin beklediği okunmamış sayısı metnini uzlaştır; gerçek sayacı koru.

### 2. Tam mobil test koşusundaki ek uyuşmazlıklar

Kanıt/bağlam: [apps/swansport_app/test/explore_layout_test.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_app/test/explore_layout_test.dart>) · [apps/swansport_app/test/mobile_glass_chrome_test.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_app/test/mobile_glass_chrome_test.dart>) · [apps/swansport_app/test/reference_header_test.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_app/test/reference_header_test.dart>) · [build/project-inventory-mobile-tests.log](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/build/project-inventory-mobile-tests.log>).

- [ ] **SW-011 · S · P1** — Keşfet testinde bulunamayan Öne Çıkan Duyurular beklentisini güncel ekran ve ürün kararıyla uzlaştır.
- [ ] **SW-012 · S · P1** — Cam header testinin altı BackdropFilter beklentisini güncel ortak kabukla uzlaştır; görsel kabulü koru.
- [ ] **SW-013 · S · P1** — 320/393px açık/koyu header testlerindeki ortalanmış başlık ve 48dp kontrol beklentilerini güncel uygulamayla uzlaştır.
- [ ] **SW-014 · S · P0** — Header oluşturma eyleminin misafir işlem kapısı testindeki başarısızlığı araştır; gerçek hesap kapısını doğrula.
- [ ] **SW-015 · S · P1** — Kaydırma kenarında tam genişlik tint paneli bulunmaması testindeki başarısızlığı güncel görsel sözleşmeyle uzlaştır.

### 3. CI ve yayın kalitesi

Kanıt/bağlam: [.github/workflows/ci.yml](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.github/workflows/ci.yml>) · [.github/workflows/build_ios.yml](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.github/workflows/build_ios.yml>) · [.github/workflows/release_android.yml](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.github/workflows/release_android.yml>) · [.github/workflows/build_console_web.yml](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.github/workflows/build_console_web.yml>).

- [ ] **SW-016 · S · P0** — Ana CI'ye tam mobil test koşusunu ekle; mevcut üç dosyalık seçim tüm mobil regresyonları kapsamıyor.
- [ ] **SW-017 · S · P0** — Ana CI'ye konsol testlerini ekle; başarısız konsol paketi yayın öncesinde görünür olsun.
- [ ] **SW-018 · S · P1** — Biçim kontrolündeki continue-on-error davranışını karara bağla; zorunlu kabul edilen ihlaller yayını durdursun.
- [ ] **SW-019 · S · P1** — CI ve Android/konsol yayınında hareketli stable yerine doğrulanmış Flutter sürümünü sabitle.
- [ ] **SW-020 · G · P0** — Mobil, konsol ve SQL kontrollerini geçen aynı commit'ten yayın üretmeyi zorunlu kıl.
- [ ] **SW-021 · G · P1** — SQL davranış testlerini ve Node gönderici testlerini CI'nin açık bir işi haline getir.
- [ ] **SW-022 · G · P1** — Migration, SSS, bildirim rotası ve mobil jeton denetimlerini CI'de ayrı sonuçlarla raporla.
- [ ] **SW-023 · G · P1** — Test başarısızlığında günlük ve ilgili ekran görüntülerini sınırlı süre artifact olarak sakla.
- [ ] **SW-024 · G · P1** — Yayın işlerine korumalı üretim ortamı ve gerekli kabul sonucu bağımlılığı ekle.
- [ ] **SW-025 · G · P2** — Yeni kodun kalite borcunu eski info/lint birikiminden ayıran ölçülebilir analiz eşiği oluştur.

### 4. Canlı sürüm ve migration eşliği

Kanıt/bağlam: [docs/production-rollout-0107.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/production-rollout-0107.md>) · [docs/mobile-release-1.0.1-58.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/mobile-release-1.0.1-58.md>) · [docs/federation-publishing-center-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/federation-publishing-center-verification.md>) · [docs/club-workflows-roadmap.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/club-workflows-roadmap.md>).

- [ ] **SW-026 · D · P0** — Son belgelenen canlı 0107 durumunu bugün gerçek şemayla karşılaştır; sonraki uygulanmış dosyaları varsayma.
- [ ] **SW-027 · R · P0** — 0126–0131 federasyon yayın merkezi migrationlarının canlı durumunu doğrula; raporda uygulanmadıkları yazıyor.
- [ ] **SW-028 · R · P0** — 0133 bugünkü antrenman RSVP migrationının canlı ve yeni istemciyle uyumunu doğrula.
- [ ] **SW-029 · R · P0** — 0134–0138 duyuru, sezon, envanter ve transfer zincirinin canlı durumunu doğrula.
- [ ] **SW-030 · D · P0** — 0108–0125 arası tesis, hakem, kimlik, profil ve güvenlik değişiklikleri için dosya bazlı kurulum matrisi çıkar.
- [ ] **SW-031 · D · P0** — Tarih damgalı yorum yanıtları migrationını numaralı zincirle birlikte kurulum sırasına dahil et.
- [ ] **SW-032 · G · P0** — Her migrationın kaynağını, özetini, uygulanma zamanını ve sonucunu tutan güvenilir canlı kayıt oluştur.
- [ ] **SW-033 · D · P0** — Güncel mobil/web istemcinin çağırdığı RPC ve sütunları gerçek parametrelerle sunucuda kontrol et.
- [ ] **SW-034 · D · P1** — Üretimdeki özellik bayraklarını SQL seed seviyesinden bağımsız kaydet; açık özellikleri gerçek hesaplarla dene.
- [ ] **SW-035 · G · P1** — Eski mobil sürümlerin yeni sunucuyla uyumu ve sorunlu özelliği geri çekme yöntemini yayın kaydına ekle.

### 5. Apple, iOS ve TestFlight

Kanıt/bağlam: [.github/workflows/build_ios.yml](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.github/workflows/build_ios.yml>) · [apps/swansport_app/ios/Runner/Info.plist](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_app/ios/Runner/Info.plist>) · [docs/match-following-ios-push-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/match-following-ios-push-verification.md>) · [docs/mobile-release-1.0.1-58.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/mobile-release-1.0.1-58.md>) · [Resmi kaynak](https://developer.apple.com/news/upcoming-requirements/?id=02032026a) · [Resmi kaynak](https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationwheninuseusagedescription) · [Resmi kaynak](https://developer.apple.com/programs/enroll/).

- [ ] **SW-036 · R · P0** — Apple Developer üyeliği ve doğru bireysel/kuruluş hesabı üzerinden dağıtım sahipliğini tamamla.
- [ ] **SW-037 · D · P0** — com.swansport.app App ID ve App Store Connect uygulama kaydını doğru takımla eşleştir.
- [ ] **SW-038 · D · P0** — Distribution sertifikası, provisioning profili ve API yükleme yetkisinin gerçek imzalı derlemede çalıştığını doğrula.
- [ ] **SW-039 · D · P0** — Firebase iOS uygulaması, gerçek plist ve APNs anahtarının bundle/proje/takım eşleşmesini doğrula.
- [ ] **SW-040 · S · P0** — Info.plist'e eksik NSLocationWhenInUseUsageDescription açıklamasını ekle; mevcut konum çağrısını cihazda dene.
- [ ] **SW-041 · D · P0** — İmzalı son paketin Firebase config ve entitlement incelemesini unsigned önizlemeden ayrı yap.
- [ ] **SW-042 · D · P0** — Xcode/SDK sürümünün güncel App Store yükleme şartlarını karşıladığını build günlüğünden doğrula.
- [ ] **SW-043 · D · P0** — Gerçek iPhone'da temiz kurulum, ilk açılış, mevcut kurulum üstüne yükseltme ve oturum korunmasını dene.
- [ ] **SW-044 · D · P1** — iOS fotoğraf/kamera/dosya seçimi, takvim aktarımı, pano ve dış harita açılışını fiziksel cihazda dene.
- [ ] **SW-045 · D · P1** — iOS arka plan dönüşü, düşük bellek, bildirim izni reddi ve ayarlardan izin iptalini doğrula.

### 6. Mağaza hazırlığı ve Android dağıtımı

Kanıt/bağlam: [.github/RELEASES.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.github/RELEASES.md>) · [.github/workflows/release_android.yml](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.github/workflows/release_android.yml>) · [docs/mobile-release-1.0.1-58.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/mobile-release-1.0.1-58.md>) · [Resmi kaynak](https://developer.apple.com/app-store/review/guidelines/).

- [ ] **SW-046 · D · P0** — Mağaza açıklaması ve ekran görüntülerini gerçekten açık olan özelliklere göre hazırla.
- [ ] **SW-047 · D · P0** — Gizlilik politikası, destek adresi ve veri toplama beyanlarını uygulamanın gerçek veri akışıyla eşleştir.
- [ ] **SW-048 · D · P0** — Yaş derecelendirmesi sorularını sosyal içerik, mesaj ve çocuk kullanıcı akışına göre yanıtla.
- [ ] **SW-049 · D · P0** — İnceleme ekibine kullanılabilir ve kapsamı açıklanmış demo hesapları sağla.
- [ ] **SW-050 · D · P1** — Kullanılan SDK'ların privacy manifest ve gerekli API gerekçelerini son iOS arşivinde incele.
- [ ] **SW-051 · D · P1** — Şifreleme/ihracat beyanını kullanılan gerçek kütüphane ve işlevlerle doğrula.
- [ ] **SW-052 · D · P1** — Hedeflenen mağaza bölgeleri ile gereken satıcı ve iletişim bilgilerini belirle.
- [ ] **SW-053 · G · P1** — Google Play hedefleniyorsa mevcut imzalı APK hattına AAB ve mağaza test kanalı ekle.
- [ ] **SW-054 · D · P1** — Android'de önceki imzalı kurulum üzerine yükseltmede hesap, veri ve çevrimdışı taslakların korunduğunu dene.
- [ ] **SW-055 · G · P1** — Kademeli mağaza yayını ve sorun halinde dağıtımı durdurma sorumluluğunu tanımla.

### 7. Hesap, telefon ve kimlik doğrulama

Kanıt/bağlam: [docs/sms-provider-setup.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/sms-provider-setup.md>) · [docs/production-rollout-0107.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/production-rollout-0107.md>) · [docs/mernis-identity-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/mernis-identity-verification.md>) · [apps/swansport_app/lib/features/verification/presentation/nfc_identity_sheet.dart](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_app/lib/features/verification/presentation/nfc_identity_sheet.dart>).

- [ ] **SW-056 · R · P0** — Gerçek SMS sağlayıcısını kur ve telefon doğrulama teslimini dene; son canlı raporda sağlayıcı kapalı.
- [ ] **SW-057 · D · P1** — Yanlış/süresi dolmuş OTP, yeniden gönderim ve sağlayıcı kesintisini gerçek telefonla dene.
- [ ] **SW-058 · D · P1** — Mevcut hesabın telefon değiştirme akışını yeni hesap oluşturmadan doğrula.
- [ ] **SW-059 · D · P0** — E-posta doğrulama ve parola sıfırlama bağlantılarının doğru mobil/web hedefinde açıldığını doğrula.
- [ ] **SW-060 · D · P0** — Token süresi bitmesi ve yenileme hatasında yarım kalan işlemin güvenli geri dönüşünü dene.
- [ ] **SW-061 · D · P0** — Hesap değişiminde eski kulüp, çocuk, mali veri ve yerel kuyruğun görünmediğini doğrula.
- [ ] **SW-062 · R · P2** — Otomatik KPS doğrulaması isteniyorsa kurumsal yetki ve gerçek adaptörü tamamla; mock'u kimlik onayı sayma.
- [ ] **SW-063 · R · P3** — NFC doğrulaması isteniyorsa güvenli çip okuma/doğrulama entegrasyonu kur; mevcut ekran yalnız hazırlık durumunu açıklıyor.
- [ ] **SW-064 · G · P1** — Platform ve kritik kulüp yöneticileri için çok faktörlü doğrulama seçeneği tasarla.
- [ ] **SW-065 · G · P2** — Hesap sahibine aktif oturumları görme ve belirli oturumu sonlandırma olanağı sun.

### 8. Veri gizliliği ve yetki kabulü

Kanıt/bağlam: [docs/identity-membership-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/identity-membership-verification.md>) · [supabase/migrations/0125_security_advisor_hardening.sql](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/supabase/migrations/0125_security_advisor_hardening.sql>) · [supabase/migrations/0012_security_reports.sql](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/supabase/migrations/0012_security_reports.sql>) · [docs/parent-action-center-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/parent-action-center-verification.md>) · [Resmi kaynak](https://developer.apple.com/support/offering-account-deletion-in-your-app/).

- [ ] **SW-066 · D · P0** — Muhasebeci hesabıyla ham tablo ve mali RPC çıktılarında sporcu kimliği sızmadığını doğrula.
- [ ] **SW-067 · D · P0** — Veli bağlantısı kaldırıldığında çocuk kartı, belge ve rapor erişiminin kesildiğini doğrula.
- [ ] **SW-068 · D · P0** — Antrenör/personel üyeliği iptalinde açık ekran ve doğrudan RPC erişimini yeniden sınamadan geçirme.
- [ ] **SW-069 · D · P0** — 0125 security_invoker ve fonksiyon izin sıkılaştırmasının gerçek canlı şemada uygulandığını doğrula.
- [ ] **SW-070 · D · P0** — Doğrudan API çağrılarıyla farklı kulübün UUID'sine erişim ve yazma denemelerini reddettiğini doğrula.
- [ ] **SW-071 · D · P0** — Hesap silmenin profil, Auth, sosyal içerik ve Storage nesneleri üzerindeki gerçek yaşam döngüsünü incele.
- [ ] **SW-072 · D · P0** — Tek kulüp yöneticisinin hesap silme engelini kullanıcıya uygulanabilir devir/kapatma akışıyla bağla.
- [ ] **SW-073 · D · P1** — Belge ve sağlık verilerinin log, bildirim, önizleme ve hata eklerine taşınmadığını doğrula.
- [ ] **SW-074 · G · P1** — Kişisel veri dışa aktarma, silme talebi takibi ve saklama gerekçelerini tek kullanıcı akışında topla.
- [ ] **SW-075 · G · P1** — Yetki test matrisine çok rollü kişiler ve hesapsız çocukları sürekli dahil et.

### 9. Sunucu işletimi ve geri kazanım

Kanıt/bağlam: [docs/architecture/environment-strategy.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/architecture/environment-strategy.md>) · [docs/diagnostics-center.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/diagnostics-center.md>) · [docs/production-rollout-0107.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/production-rollout-0107.md>).

- [ ] **SW-076 · D · P0** — Veritabanı yedeğinden geri yüklemeyi ayrı ortamda gerçekten dene ve süreyi kaydet.
- [ ] **SW-077 · D · P0** — Storage dosyalarının yedek ve geri kazanımını veritabanı yedeğinden ayrı doğrula.
- [ ] **SW-078 · G · P1** — Üretimden ayrılmış, kişisel veri taşımayan kalıcı kabul ortamı oluştur.
- [ ] **SW-079 · D · P1** — Cron görevlerinin varlığı, son çalışma zamanı ve hata kayıtlarını gözden geçir.
- [ ] **SW-080 · G · P1** — API/uygulama erişilebilirliği ve kritik RPC hata oranı için operasyon uyarıları oluştur.
- [ ] **SW-081 · D · P1** — Üretim URL'lerinin TLS/DNS ve konsol derin bağlantılarını farklı ağdan doğrula; eski raporlarda kabul açık.
- [ ] **SW-082 · G · P1** — Supabase, Cloudflare ve Firebase maliyet/kota eşiklerini ölç ve uyarı kur.
- [ ] **SW-083 · G · P1** — Sırların sahibi, yenileme yöntemi ve acil iptal adımlarını güvenli işletim belgesinde tut.
- [ ] **SW-084 · D · P1** — Yük altında migration/cron kilit yarışını ve dosya başına 15 saniye kilit sınırını doğrula.
- [ ] **SW-085 · G · P1** — Olay anında sorumlu, hizmeti geri getirme sırası ve kullanıcı iletişimi sürecini belirle.

### 10. İlk kullanım ve ana sayfa

Kanıt/bağlam: [docs/product-development-roadmap.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/product-development-roadmap.md>) · [docs/home-quick-access-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/home-quick-access-verification.md>) · [docs/today-training-rsvp-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/today-training-rsvp-verification.md>).

- [ ] **SW-086 · G · P1** — Kulüp kurulumunu sezon sihirbazı, personel daveti, kadro ve ilk programla tamamlanan rehbere dönüştür.
- [ ] **SW-087 · G · P1** — İlk kullanımda kişinin mevcut kulübe katılma ve yeni kulüp kurma seçeneklerini daha anlaşılır ayır.
- [ ] **SW-088 · G · P1** — Kullanıcının yarım bıraktığı kurulum adımına güvenli biçimde dönmesini sağla.
- [ ] **SW-089 · G · P1** — Ana sayfadaki mevcut görevleri önem ve son tarihe göre sırala; aynı işi iki kartta çoğaltma.
- [ ] **SW-090 · G · P2** — Birden fazla kulüp/çocuk bağlamını işlem öncesinde açıkça göster.
- [ ] **SW-091 · D · P1** — Bugünkü antrenman yanıtını gerçek yoklamadan kullanıcı metni ve sonuç ekranında ayırdığını doğrula.
- [ ] **SW-092 · D · P1** — İstanbul gece sınırı, antrenman başlangıcı ve eski form çakışmasını gerçek hesaplarla dene.
- [ ] **SW-093 · G · P2** — Hızlı erişim tercihleri için isteğe bağlı cihazlar arası eşitleme ekle.
- [ ] **SW-094 · D · P2** — Boş hızlı erişim seçimini varsayılana dönüştürmeden koruduğunu cihaz yükseltmesinde dene.
- [ ] **SW-095 · G · P2** — Boş ana sayfada kullanıcının yapabileceği tek uygun sonraki adımı göster.

### 11. Kulüp, personel, kadro ve sezon

Kanıt/bağlam: [docs/season-setup-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/season-setup-verification.md>) · [docs/club-workflows-roadmap.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/club-workflows-roadmap.md>) · [docs/general-revision-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/general-revision-verification.md>).

- [ ] **SW-096 · D · P0** — Hesapsız sporcunun eklenme, sezon seçimi ve veliyle yönetim yollarını gerçek kulüpte doğrula.
- [ ] **SW-097 · D · P1** — Mevcut üyeyi sporcu kaydına bağlarken yanlış kişi ve tekrar bağlama denemelerini doğrula.
- [ ] **SW-098 · D · P1** — Sezon açılışında çift gönderim ve iki yöneticinin aynı anda işlem yapmasını gerçek PostgreSQL oturumlarıyla dene.
- [ ] **SW-099 · D · P1** — Eski kadro önizlemesinden yeni sezona seçilen sporcuların doğru takıma yazıldığını doğrula.
- [ ] **SW-100 · G · P2** — Mevcut sezon hazırlığını, eski kadroyu değiştirmeden toplu geçiş önizlemesiyle geliştir.
- [ ] **SW-101 · G · P2** — Excel/CSV kadro içe aktarmada hata önizlemesi, eşleştirme ve mükerrer tespiti ekle.
- [ ] **SW-102 · G · P2** — Personel ve sporcu davetlerinin bekleyen, süresi dolan ve yeniden gönderilen durumlarını tek yerde topla.
- [ ] **SW-103 · G · P2** — Kulüpten ayrılan personelin devir teslimini açık görevler ve ekipmanlarla ilişkilendir.
- [ ] **SW-104 · G · P2** — Birden fazla takımda bulunan sporcunun çakışan programlarını yöneticiye göster.
- [ ] **SW-105 · G · P2** — Kulüp şubeleri büyüyecekse şube kapsamını mevcut kulüp/takım yetkileriyle tasarla.

### 12. Takvim ve program

Kanıt/bağlam: [docs/unified-calendar-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/unified-calendar-verification.md>) · [docs/club-workflows-roadmap.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/club-workflows-roadmap.md>) · [docs/season-setup-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/season-setup-verification.md>).

- [ ] **SW-106 · D · P1** — Birleşik takvimde resmi maç, kulüp etkinliği ve veli sonucunun doğru yetkiyle geldiğini hesaplı dene.
- [ ] **SW-107 · D · P1** — Tek seferlik ICS aktarımını fiziksel iOS ve Android takvim uygulamalarına içe aktararak doğrula.
- [ ] **SW-108 · R · P2** — Değişikliklerin otomatik izlenmesi isteniyorsa mevcut tek seferlik ICS dışa aktarmaya abonelik takvimi ekle.
- [ ] **SW-109 · G · P2** — Takvim aboneliğinde özel bağlantı iptali ve erişim değişikliğinin nasıl yansıyacağını tasarla.
- [ ] **SW-110 · D · P1** — Tekrarlı programda yalnız bu gün, gelecek günler ve tüm seri değişikliklerinin sonucunu karşılaştır.
- [ ] **SW-111 · G · P2** — Toplu program düzenlemesinde etkilenecek etkinlik ve bildirim sayısını kaydetmeden önce göster.
- [ ] **SW-112 · G · P2** — Antrenör, takım ve tesis müsaitliğini gerçek kayıtlar üzerinden birlikte göster.
- [ ] **SW-113 · G · P2** — Erteleme ve iptaller için ilgili kişilerin yanıtlarını yeni zamanla ilişkilendir.
- [ ] **SW-114 · G · P2** — Saat dilimi farklı cihazlarda Türkiye saati ve tüm gün etkinliği gösterimini açıklaştır.
- [ ] **SW-115 · G · P2** — Takvim arama ve filtre tercihlerini kullanıcıya geri dönüldüğünde koru.

### 13. Yoklama ve çevrimdışı çalışma

Kanıt/bağlam: [docs/offline-attendance-design.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/offline-attendance-design.md>) · [docs/saha-operations-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/saha-operations-verification.md>).

- [ ] **SW-116 · R · P0** — Çevrimdışı yoklamayı herkese açmadan Android/iOS zorla kapatma ve yeniden açma kabulünü tamamla.
- [ ] **SW-117 · D · P0** — İki cihazın aynı yoklamayı değiştirmesinde sürüm çakışmasının sessizce veri ezmediğini doğrula.
- [ ] **SW-118 · D · P0** — Çevrimdışı kuyruk varken hesap değişimi ve çıkışta başka hesaba veri taşınmadığını doğrula.
- [ ] **SW-119 · D · P1** — Kadro önbelleği eskidiğinde yeni işaretin durduğunu, eski taslağın korunduğunu doğrula.
- [ ] **SW-120 · D · P1** — Kuyruk kapasitesi ve uzun süre gönderilemeyen işlemler için gerçek cihazdaki açıklamaları dene.
- [ ] **SW-121 · G · P2** — Senkronizasyon kuyruğunu son hata, bekleme nedeni ve açık yeniden denemeyle daha anlaşılır hale getir.
- [ ] **SW-122 · G · P2** — Yoklama düzeltmelerini yetkili kişi, gerekçe ve önceki değerle kolay incelenir yap.
- [ ] **SW-123 · G · P2** — Devamsızlık eğilimini kesin sağlık/başarı hükmü vermeden veli ve antrenöre özetle.
- [ ] **SW-124 · G · P2** — Çevrimdışı desteklenen işlemleri ekran üzerinde açıkça belirt; diğer işlemlerde bağlantı durumunu göster.
- [ ] **SW-125 · G · P3** — Saha işleyişi ihtiyaç gösterirse suistimal önlemleriyle süreli QR yoklama yardımını değerlendir.

### 14. Antrenman motoru ve antrenör işleri

Kanıt/bağlam: [docs/training-cockpit-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/training-cockpit-verification.md>) · [docs/multi-branch-training-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/multi-branch-training-verification.md>) · [docs/training-archetypes-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/training-archetypes-verification.md>).

- [ ] **SW-126 · R · P1** — Antrenman sayaç ve tur taslaklarının RAM sınırını kalıcı, hesap/oturum anahtarlı kurtarmayla gider.
- [ ] **SW-127 · D · P0** — Sunucuda kilitli setin eski istemci veya ağ tekrarında değiştirilemediğini gerçek RPC yolunda dene.
- [ ] **SW-128 · D · P1** — Antrenör/yardımcı yetkisi iptal edilirken açık oturumdan yeni kayıt reddini doğrula.
- [ ] **SW-129 · D · P1** — Duraklatma ve arka plandan dönüşte sürenin sunucu zamanı ile tutarlı kaldığını cihazda doğrula.
- [ ] **SW-130 · G · P2** — Mevcut branş şablonlarına sürümlü kulüp şablon kütüphanesi ve favoriler ekle.
- [ ] **SW-131 · G · P2** — Önceki antrenmanı yeni tarih için kopyalamada sonuç ve katılımcı geçmişini kopyalamadan önizleme sun.
- [ ] **SW-132 · G · P2** — Planlanan içerikle yapılan içeriği karşılaştıran sade seans özeti ekle.
- [ ] **SW-133 · G · P2** — Kalabalık antrenmanda grup/istasyon geçişlerini mevcut oturum motoruyla ilişkilendir.
- [ ] **SW-134 · G · P2** — Antrenörün kişisel notları ile sporcu/veliyle paylaşılabilir geri bildirimi ayrı izinlerle yönet.
- [ ] **SW-135 · G · P2** — Farklı metrikleri tek puana zorlamadan branşa özgü karşılaştırma görünümü sun.

### 15. Performans ve gelişim raporu

Kanıt/bağlam: [docs/development-report-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/development-report-verification.md>) · [docs/branch-match-protocol-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/branch-match-protocol-verification.md>) · [docs/official-federation-result-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/official-federation-result-verification.md>).

- [ ] **SW-136 · D · P1** — Dönem raporunda veli, sporcu, personel ve yalnız muhasebeci hesaplarının gerçek kapsamını doğrula.
- [ ] **SW-137 · D · P1** — Rapor açıkken ölçüm veya veli bağı değiştiğinde dışa aktarımın yeniden yetki kontrolünü dene.
- [ ] **SW-138 · G · P2** — Mevcut dönem raporuna önizlemeli PDF çıktısı ekle.
- [ ] **SW-139 · G · P2** — Farklı dönemleri aynı birim ve aynı test protokolüyle karşılaştır.
- [ ] **SW-140 · G · P2** — Hedef durumunu yalnız güncel değer yerine izinli tarihsel değişimle genişlet.
- [ ] **SW-141 · G · P2** — Ölçüm kaynağı, tarihi ve koşullarını karşılaştırma ekranında göster.
- [ ] **SW-142 · G · P2** — Eksik veri miktarını ve karşılaştırmanın hangi kayıtlara dayandığını raporda açıkla.
- [ ] **SW-143 · G · P2** — Kişisel gelişim uyarılarını önce antrenör incelemesine sun; doğrulanmamış kesin tahmin yayımlama.
- [ ] **SW-144 · G · P3** — Video analizi isteniyorsa izin, saklama, antrenör iş akışı ve ölçüm doğruluğuyla sınırlı pilot tasarla.
- [ ] **SW-145 · G · P3** — Giyilebilir cihaz entegrasyonunu desteklenen ölçüm ve açık kullanıcı tercihi üzerinden değerlendir.

### 16. Sağlık, beslenme ve kişisel ekipman

Kanıt/bağlam: [docs/club-staff-operations-phase-5-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/club-staff-operations-phase-5-verification.md>) · [docs/product/screen_12_medical_center_spec.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/product/screen_12_medical_center_spec.md>) · [docs/demo-action-audit.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/demo-action-audit.md>).

- [ ] **SW-146 · D · P0** — Aktif sağlık yetkisi olmayan doktor etiketli kişinin kısıt kaldıramadığını gerçek hesapla doğrula.
- [ ] **SW-147 · D · P0** — İdari dinlenme kaldırılınca tıbbi kısıtın devam ettiğini uçtan uca doğrula.
- [ ] **SW-148 · D · P1** — Sağlık görevlisinin kulüpten ayrılmasıyla mevcut ekran ve yazma yetkisinin kapandığını dene.
- [ ] **SW-149 · G · P2** — İyileşme dönüşünü yalnız yetkili sağlık görevlisinin işaretlediği aşamalarla yönet.
- [ ] **SW-150 · G · P2** — Belge süresi, antrenman uygunluğu ve veli yapılacaklarını mevcut kayıtlardan ilişkilendir.
- [ ] **SW-151 · G · P2** — Beslenme/su hedeflerinin kaynağını ve güncelliğini kullanıcıya göster.
- [ ] **SW-152 · D · P1** — Beslenme ve kişisel ekipman özelliklerinin eski prototip raporuna göre değil güncel gerçek servisleriyle kabulünü yap.
- [ ] **SW-153 · G · P2** — Beslenme kayıtlarında düzenli kullanım için hızlı tekrar ve geçmiş düzeltme akışını geliştir.
- [ ] **SW-154 · G · P2** — Kişisel ekipmanın bakım, ayar ve değişim geçmişini tarihli kayda dönüştür.
- [ ] **SW-155 · G · P3** — Hassas sağlık verisini genişletmek ancak açık ürün ihtiyacı, dar erişim ve saklama tasarımıyla değerlendir.

### 17. Veli ve çocuk işlemleri

Kanıt/bağlam: [docs/parent-action-center-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/parent-action-center-verification.md>) · [docs/coach-guardian-result-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/coach-guardian-result-verification.md>) · [docs/live-match-spectator-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/live-match-spectator-verification.md>).

- [ ] **SW-156 · D · P0** — Bir çocuğa iki veli ve farklı kulüplerde kardeşler senaryosunu gerçek hesaplarla doğrula.
- [ ] **SW-157 · D · P0** — Giriş profili olmayan çocuğun belgeleri, yanıtları ve gelişim raporunun çalıştığını doğrula.
- [ ] **SW-158 · D · P0** — Veli bağı kaldırıldıktan sonra eski bağlantı ve eski imzalı URL davranışını incele.
- [ ] **SW-159 · R · P2** — Genel hukuki izin talebi gerekiyorsa mevcut etkinlik yanıtından ayrı, sürümlü izin akışı kur.
- [ ] **SW-160 · G · P2** — Gezi/ulaşım/etkinlik izinlerini amaç, tarih ve güncel veli ilişkisiyle ilişkilendir.
- [ ] **SW-161 · D · P0** — Kamusal sporcu adı rızası geri çekildiğinde yeni yayın okumalarının maskelendiğini doğrula.
- [ ] **SW-162 · G · P2** — Veliye çocuğun yaklaşan son tarihlerini tek takvim ve işlem listesinde sun.
- [ ] **SW-163 · G · P2** — Çocuk belirli yaş eşiğine geldiğinde hesap ve görünürlük geçişini anlaşılır rehberle yönet.
- [ ] **SW-164 · G · P2** — Veli ile antrenör iletişiminde hangi çocuk/takım için yazıldığını açıkça göster.
- [ ] **SW-165 · G · P2** — Veli davetinin yanlış kişiye gitmesi veya süresi dolması için iptal/yeniden davet yolunu sadeleştir.

### 18. Duyurular ve kulüp iletişimi

Kanıt/bağlam: [docs/club-workflows-roadmap.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/club-workflows-roadmap.md>) · [docs/parent-action-center-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/parent-action-center-verification.md>).

- [ ] **SW-166 · D · P1** — Duyuru metni her değiştiğinde yeni revizyon ve yeni onay gereksinimini gerçek iki hesapla doğrula.
- [ ] **SW-167 · D · P1** — Okundu ve açık onay sayılarının birbirine karışmadığını yönetici/üye ekranlarında doğrula.
- [ ] **SW-168 · D · P1** — Duyuru erişimi olmayan velinin yalnız çocuk bağı üzerinden metne erişemediğini doğrula.
- [ ] **SW-169 · G · P2** — Mevcut duyurulara zamanlı yayın ve önizlemeli hedef kitle seçimi ekle.
- [ ] **SW-170 · G · P2** — Son tarihli yanıt bekleyen duyurular için sınırlı ve kullanıcı tercihine saygılı hatırlatma tasarla.
- [ ] **SW-171 · G · P2** — Duyuru şablonlarını kulüp içinde tekrar kullanılabilir yap.
- [ ] **SW-172 · G · P2** — Eski duyurunun değiştirilmesi halinde yeniden bildirimin kimlere gideceğini önceden göster.
- [ ] **SW-173 · G · P2** — Acil duyuru kanalını gereksiz toplu bildirimden koruyacak yetki ve sıklık sınırı koy.
- [ ] **SW-174 · G · P2** — Duyuru aramasına tarih, takım, sabitlenme ve yanıt durumu filtreleri ekle.
- [ ] **SW-175 · G · P2** — Toplu iletişimde teslim, okuma ve onayın farklı sonuçlar olduğunu yöneticiye açıkça göster.

### 19. Aidat, mali işler ve ödeme

Kanıt/bağlam: [docs/finance-adjustment-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/finance-adjustment-verification.md>) · [docs/platform-mission-control-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/platform-mission-control-verification.md>) · [docs/product/screen_14_financial_management_spec.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/product/screen_14_financial_management_spec.md>).

- [ ] **SW-176 · D · P0** — Muhasebeci, kulüp yöneticisi ve kendi talebini onaylama yasağını gerçek mali hesaplarla doğrula.
- [ ] **SW-177 · D · P0** — Eski mali düzeltmelerde mutabakat sorunlarını gerçek belgelerle incele; otomatik geçmiş para hareketi üretme.
- [ ] **SW-178 · D · P0** — İki eşzamanlı iade/onay işleminde toplam tutar sınırını gerçek PostgreSQL oturumlarıyla dene.
- [ ] **SW-179 · D · P1** — Kapalı döneme doğrudan yazma reddi ve bugüne ters kayıt zincirini uçtan uca dene.
- [ ] **SW-180 · G · P1** — Online ödeme alınacaksa sağlayıcı, imzalı webhook, tekrar işleme koruması ve mutabakat akışını birlikte kur.
- [ ] **SW-181 · G · P1** — Ödeme başarısı, bekleyen banka sonucu ve iade durumunu kullanıcıya ayrı göster.
- [ ] **SW-182 · G · P2** — Aidat hatırlatmalarını vade, veli ilişkisi, iletişim tercihi ve tekrar sınırıyla geliştir.
- [ ] **SW-183 · G · P2** — Burs/indirim değişikliklerinin gelecek tahakkuklara etkisini kaydetmeden önce göster.
- [ ] **SW-184 · G · P2** — Kulüp mali raporlarını gerçek dönem, kasa ve takım filtreleriyle paylaşılabilir yap.
- [ ] **SW-185 · G · P3** — E-fatura/e-arşiv ihtiyacını kuruluş ve mali süreç gereksinimi netleşince sağlayıcıyla bütünleştir.

### 20. Kulüp envanteri ve transfer

Kanıt/bağlam: [docs/club-staff-operations-phase-5-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/club-staff-operations-phase-5-verification.md>) · [docs/club-workflows-roadmap.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/club-workflows-roadmap.md>).

- [ ] **SW-186 · D · P0** — Kısmi iadede quantity/resolved_quantity ayrımının mobil ve konsol stok toplamlarında korunduğunu doğrula.
- [ ] **SW-187 · D · P0** — İki personelin aynı zimmeti iade etme yarışını gerçek oturumlarla sınamadan geçirme.
- [ ] **SW-188 · R · P2** — Kulüp envanterinde bakım/onarım ve kullanım dışına ayırma düzenleme akışlarını tamamla.
- [ ] **SW-189 · R · P2** — Mevcut stok artırma işlemi için yetkili ve denetlenebilir kullanıcı akışını tamamla.
- [ ] **SW-190 · R · P1** — Büyük envanter listelerine sunucu sayfalaması ekle.
- [ ] **SW-191 · G · P2** — Zimmette teslim alanın kabulü ve teslim durumunun takip edilmesini değerlendir.
- [ ] **SW-192 · G · P2** — Ekipmana barkod/QR etiketi ve mevcut kayda doğrudan erişim ekle.
- [ ] **SW-193 · D · P0** — Transferde kaynak, hedef, sporcu/veli ve federasyon son karar yetkisini gerçek hesaplarla doğrula.
- [ ] **SW-194 · D · P0** — Transfer sırasında ilişki/üyelik değişimi ve belirsiz ağ yanıtında tekrar gönderimi dene.
- [ ] **SW-195 · G · P2** — Transfer taleplerine süre, eksik belge ve beklenen taraf görünümü ekle; resmî tescil yetkisini koru.

### 21. Tesis, rezervasyon ve partner

Kanıt/bağlam: [docs/saha-operations-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/saha-operations-verification.md>) · [docs/venue-guest-action-gate-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/venue-guest-action-gate-verification.md>) · [supabase/migrations/0108_facility_reservation_conflicts.sql](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/supabase/migrations/0108_facility_reservation_conflicts.sql>).

- [ ] **SW-196 · D · P0** — 0108 tesis çakışması motorunun canlı kurulum ve gerçek rezervasyon yazma yollarını doğrula.
- [ ] **SW-197 · D · P0** — Aynı tesis/saat için iki hesabın eşzamanlı rezervasyon denemesini gerçek PostgreSQL'de sınamadan geçirme.
- [ ] **SW-198 · D · P1** — Kort bekleme sırasının beş dakikalık teklif, süre dolması ve iptalde doğru kişiye ilerlediğini dene.
- [ ] **SW-199 · D · P1** — Halı saha görev devrinin süre dolması ve geri alma sırasında açık formu yetkisiz bıraktığını doğrula.
- [ ] **SW-200 · R · P2** — Tesis fotoğraf ve zemin bilgisini yetkili kişinin yönetebildiği ekranı tamamla.
- [ ] **SW-201 · G · P2** — Tesis bakım/kapalı saatlerini rezervasyon ve gerçek müsaitlikle ilişkilendir.
- [ ] **SW-202 · G · P2** — Tesis kullanımını mali rapora bağlarken rezervasyon ile gerçek tahsilatı ayrı tut.
- [ ] **SW-203 · G · P2** — Partner aramasında şehir, branş, zaman ve uygun seviye filtrelerini gerçek veriye göre genişlet.
- [ ] **SW-204 · D · P1** — Partner eşleşmesi, engelleme ve tekrar ping durumunda tek ve doğru iletişimin oluştuğunu dene.
- [ ] **SW-205 · G · P2** — No-show/iptal politikası eklenecekse yanlış karar için itiraz ve yetkili düzeltme akışı tasarla.

### 22. Sosyal akış ve mesajlaşma

Kanıt/bağlam: [docs/demo-action-audit.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/demo-action-audit.md>) · [docs/identity-membership-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/identity-membership-verification.md>) · [docs/product/mvp-scope.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/product/mvp-scope.md>).

- [ ] **SW-206 · D · P0** — Gönderi görünürlüğü ve iki yönlü engellemenin arama, profil, akış ve paylaşılan kartlarda tutarlı olduğunu doğrula.
- [ ] **SW-207 · D · P0** — Silinen veya erişimi kaldırılan paylaşımların eski mesaj kartında başlık/görsel sızdırmadığını dene.
- [ ] **SW-208 · D · P0** — Çocuk hesabının varsayılan görünürlüğü ve dış paylaşım kısıtlarını gerçek kayıtlarla dene.
- [ ] **SW-209 · G · P1** — Şikâyet kuyruğuna müdahale süresi, sorumlu atama ve karar gerekçesi takibi ekle.
- [ ] **SW-210 · G · P2** — Gönderi taslağını hesap ayrımı ve güvenli yerel saklamayla kurtarılabilir yap.
- [ ] **SW-211 · G · P2** — Mesaj metni taslağını sohbet bazında geri dönüldüğünde koru.
- [ ] **SW-212 · G · P2** — Dosya/medya mesajı gerekiyorsa özel erişim, boyut sınırı ve yükleme tekrarını birlikte tasarla.
- [ ] **SW-213 · G · P2** — Mesaj gönderildi/alındı/okundu durumlarını gerçek sunucu kanıtına göre genişlet.
- [ ] **SW-214 · G · P2** — Topluluk yönetiminde üye çıkarma, duyuru sabitleme ve rol devrini tutarlı bir akışta topla.
- [ ] **SW-215 · G · P3** — Sesli/görüntülü arama veya canlı yayın talebini kullanım kanıtı ve işletim maliyetiyle ayrı ürün kararı olarak ele al.

### 23. Federasyon ve resmi işlemler

Kanıt/bağlam: [docs/federation-console-phase-4-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/federation-console-phase-4-verification.md>) · [docs/federation-publishing-center-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/federation-publishing-center-verification.md>) · [docs/official-federation-result-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/official-federation-result-verification.md>).

- [ ] **SW-216 · R · P1** — Disiplin sürecinde tipli ve donmuş antrenör sevki akışını tamamla.
- [ ] **SW-217 · R · P1** — Disiplin kararına itiraz ve karar revizyonunu immutable geçmişle tasarla.
- [ ] **SW-218 · R · P1** — Disiplin tebligatı ile kamusal bülteni ayrı yetki ve içerikle tamamla.
- [ ] **SW-219 · R · P1** — allocate_official_match_facility RPC'sini gerçek yetkili tesis tahsis ekranına bağla.
- [ ] **SW-220 · R · P1** — Kilitlenmiş gelecek esamenin yeni ceza sonrası yeniden onay/düzeltme sürecini tamamla.
- [ ] **SW-221 · D · P0** — Özel disiplin gerekçesi ile yayımlanmış public_summary ayrımını ham API ve mobilde doğrula.
- [ ] **SW-222 · D · P0** — Resmi sonuç düzeltmesinde CV, veli sonucu, public akış ve bildirimlerin aynı revizyonu kullandığını doğrula.
- [ ] **SW-223 · G · P2** — Federasyon görevi devri, süre sonu ve vekâlet kapsamını yönetilebilir hale getir.
- [ ] **SW-224 · G · P2** — Yayın öncesi fikstür, tesis, esame ve görevli eksiklerini tek kontrol görünümünde topla.
- [ ] **SW-225 · G · P3** — Harici federasyon entegrasyonunu yetkili API ve veri sahipliği anlaşması oluşursa değerlendir.

### 24. Hakem kokpiti ve spor protokolleri

Kanıt/bağlam: [docs/referee-cockpit-phase-3-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/referee-cockpit-phase-3-verification.md>) · [docs/branch-match-protocol-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/branch-match-protocol-verification.md>) · [docs/league-standings-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/league-standings-verification.md>).

- [ ] **SW-226 · R · P2** — Voleybol canlı hakem protokolünü mevcut futbol/basketbol/tenis kapsamına ekle.
- [ ] **SW-227 · R · P2** — Bireysel süre/derece branşlarına takım skorunu taklit etmeyen gerçek canlı detay tasarla.
- [ ] **SW-228 · R · P2** — Atletizm atma/atlama protokollerini branşa uygun ölçüm ve geçersiz deneme kurallarıyla genişlet.
- [ ] **SW-229 · R · P2** — Alternatif tenis formatlarını açık format seçimi ve doğrulanmış kurallarla genişlet.
- [ ] **SW-230 · R · P1** — Hakem belirsiz işlem taslağını uygulama kapanmasına dayanıklı, operation ID koruyan depoya taşı.
- [ ] **SW-231 · D · P0** — İki görevlinin aynı maçta eşzamanlı olay, undo ve rapor işlemini gerçek oturumlarla doğrula.
- [ ] **SW-232 · D · P0** — Görev kabulü/branş/yetki iptali sonrası açık kokpitten yazmanın reddedildiğini doğrula.
- [ ] **SW-233 · D · P1** — Güneş ışığı, tek elle kullanım, haptik ve büyük metinde canlı skor girişini fiziksel cihazda dene.
- [ ] **SW-234 · G · P2** — Olay geri alma öncesinde hangi olay ve sonucun etkileneceğini açıkça göster.
- [ ] **SW-235 · G · P3** — Foto-finiş, rekor onayı ve resmi zaman yuvarlamasını yetkili federasyon prosedürü netleşince ekle.

### 25. Canlı skor ve lig tablosu

Kanıt/bağlam: [docs/live-match-spectator-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/live-match-spectator-verification.md>) · [docs/league-standings-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/league-standings-verification.md>).

- [ ] **SW-236 · R · P1** — Canlı maç listesine mevcut 200 kayıt sınırını aşan sunucu sayfalaması ve geçmiş erişimi ekle.
- [ ] **SW-237 · R · P1** — Uzun olay geçmişinde her okumada journal oynatmanın maliyetini ölç ve gerekirse public snapshot üret.
- [ ] **SW-238 · R · P1** — Lig tablosunda tüm sezon hesaplamasını önbellek veya güvenilir snapshot ile ölçekle.
- [ ] **SW-239 · R · P1** — Örtülü rota ve arka planda veri polling'ini uygulama yaşam döngüsüne göre durdur.
- [ ] **SW-240 · R · P2** — Liglere grup ayrımı ve organizasyonun gerçek sıralama kurallarını ekle.
- [ ] **SW-241 · R · P2** — İkili averaj ve çoklu eşitlik kurallarını organizasyon bazında yapılandır.
- [ ] **SW-242 · R · P2** — Voleybol gibi branşlarda set sonucuna bağlı bonus puanlarını destekle.
- [ ] **SW-243 · R · P2** — Puan cezasını gerekçe, yürürlük ve itiraz geçmişiyle resmi tabloya bağla.
- [ ] **SW-244 · R · P2** — Eleme ağacı ve şampiyon tescilini mevcut lig puan tablosundan ayrı akış olarak ekle.
- [ ] **SW-245 · G · P2** — Maç takip ekranına anlaşılır veri güncelliği ve bağlantı kesintisi göstergesi ekle.

### 26. Bildirim motoru

Kanıt/bağlam: [docs/match-following-ios-push-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/match-following-ios-push-verification.md>) · [apps/swansport_app/functions/api/push.js](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/apps/swansport_app/functions/api/push.js>).

- [ ] **SW-246 · R · P1** — Push üretimini kalıcı gönderim kuyruğu ve hata sonrası kontrollü tekrar denemeyle güçlendir.
- [ ] **SW-247 · R · P1** — Gönderici başarısızlığını DB/bildirim kaydından operasyon ekranına kadar izlenebilir yap.
- [ ] **SW-248 · R · P1** — Kalıcı hatalı token/abonelik sonuçlarını abonelik pasifleştirmeye bağla; mevcut gone işareti tek başına temizlik değil.
- [ ] **SW-249 · R · P1** — Çok alıcılı bildirimlerde toplu işleme, eşzamanlılık sınırı ve gönderim hız kontrolü ekle.
- [ ] **SW-250 · R · P2** — Teslim ledger'ı için saklama süresi ve büyüme politikasını belirle.
- [ ] **SW-251 · R · P2** — Mevcut sabit badge=1 yerine platformla uyumlu gerçek okunmamış durumunu ve sıfırlamayı tasarla.
- [ ] **SW-252 · R · P2** — Maçta başlangıç, skor ve sonuç bildirimlerini ayrı seçebilme ekranını ekle.
- [ ] **SW-253 · D · P0** — iOS/Android açık, arka plan ve kapalı uygulamada bildirime dokununca doğru ve yetkili rotayı doğrula.
- [ ] **SW-254 · D · P1** — Bildirim izni reddi, cihaz kapatma tercihi, token yenileme ve yeniden kurulum davranışını dene.
- [ ] **SW-255 · G · P2** — Bildirim yoğunluğunu azaltmak için kişisel özet ve sessiz saat seçeneklerini mevcut tercihlerle genişlet.

### 27. Arayüz, erişilebilirlik ve cihaz performansı

Kanıt/bağlam: [docs/mobile-glass-chrome-44.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/mobile-glass-chrome-44.md>) · [docs/instagram-reference-header-46.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/instagram-reference-header-46.md>) · [docs/home-quick-access-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/home-quick-access-verification.md>).

- [ ] **SW-256 · D · P1** — Cam/blur başlık ve alt gezinmenin düşük donanımlı gerçek iPhone/Android'de kare süresi ve pil etkisini ölç.
- [ ] **SW-257 · D · P1** — 320–360px ekran ve büyük sistem yazısında tüm kritik formların kaydet/iptal düğmelerini dene.
- [ ] **SW-258 · D · P1** — VoiceOver/TalkBack ile ikon ağırlıklı beş gezinme hedefi, rozet ve form hatalarını doğrula.
- [ ] **SW-259 · D · P1** — Klavye açılınca kaydet barı, miktar girişi ve en alttaki alanların erişilebilir kaldığını doğrula.
- [ ] **SW-260 · D · P1** — Açık/koyu temada metin, hata, pasif düğme ve marka yüzeyi kontrastlarını ölç.
- [ ] **SW-261 · G · P2** — Hareket azaltma tercihine uyan başlık ve sayfa animasyonları sun.
- [ ] **SW-262 · G · P2** — Yükleniyor, boş, hata ve çevrimdışı durumlarını tüm önemli ekranlarda aynı davranış diliyle düzenle.
- [ ] **SW-263 · G · P2** — Uzun kadro, mesaj ve envanter listelerinde kaydırma ve görsel belleği maliyetini ölçüp azalt.
- [ ] **SW-264 · G · P2** — Geri dönüşte filtre, seçili çocuk/takım ve kaydırma konumunu uygun ekranlarda koru.
- [ ] **SW-265 · D · P1** — Konsolda 900px eşiği, yatay taşma, klavye gezinmesi ve erişilemeyen sekmeleri dene.

### 28. Destek, tanılama ve bakım

Kanıt/bağlam: [docs/diagnostics-center.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/diagnostics-center.md>) · [docs/diagnostic-fix-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/diagnostic-fix-verification.md>) · [.github/workflows/diagnostic-retention.yml](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.github/workflows/diagnostic-retention.yml>).

- [ ] **SW-266 · D · P1** — Tanılama izin tercihinin çıkış/giriş ve farklı cihazda beklenen biçimde uygulandığını doğrula.
- [ ] **SW-267 · D · P1** — Günlük fiziksel ekran görüntüsü temizliğinin canlıda çalıştığını gerçek Storage sonucuyla doğrula.
- [ ] **SW-268 · D · P1** — Tanılama eki silme hatasında referansın korunup sonraki denemede temizlendiğini kabul ortamında dene.
- [ ] **SW-269 · R · P2** — Native çökme ve ayrı isolate hatalarını mevcut uygulama tanılamasına uygun bir toplama yöntemiyle tamamla.
- [ ] **SW-270 · R · P2** — Web küçültülmüş stack trace'lerini gizli kaynak haritası veya eşdeğer sürümleme yöntemiyle çözülebilir yap.
- [ ] **SW-271 · G · P1** — Kritik hata ve başarısız temizlik işleri için ekip uyarısı ve sorumlu ataması oluştur.
- [ ] **SW-272 · G · P2** — Destek talebini ilgili sürüm, işlem ve düzeltme teyidiyle kullanıcıya anlaşılır zaman çizelgesinde sun.
- [ ] **SW-273 · G · P2** — Destek kuyruğuna öncelik, atama ve bekleme süresi görünümü ekle.
- [ ] **SW-274 · G · P2** — SSS aramalarında sonuç bulunmayan konuları kişisel veri toplamadan içerik iyileştirmesine dönüştür.
- [ ] **SW-275 · G · P2** — Hata raporunda ekran görüntüsü seçmeden önce hassas alanları kapatma/redaksiyon yardımı sun.

### 29. Ticari model ve pazaryeri

Kanıt/bağlam: [docs/platform-mission-control-verification.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/platform-mission-control-verification.md>) · [docs/demo-action-audit.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/demo-action-audit.md>) · [docs/product/mvp-scope.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/product/mvp-scope.md>).

- [ ] **SW-276 · R · P1** — Mission Control signup kill-switch değerlerini gerçekten sunucu kayıt işlemlerine bağla.
- [ ] **SW-277 · R · P1** — Bakım modunun Ana Akış sınırını aşacak ürün ihtiyacı varsa sunucu yazma kapılarıyla global davranışı tamamla.
- [ ] **SW-278 · R · P2** — Komisyon ayarlarını gerçek ödeme/mutabakatta uygulamadan ticari tahsilat kuralı gibi sunma.
- [ ] **SW-279 · G · P2** — Paket haklarını sunucuda denetlenen limit ve özelliklerle ilişkilendir.
- [ ] **SW-280 · G · P2** — Abonelik alınacaksa deneme, yenileme, iptal ve hak bitişini birlikte tasarla.
- [ ] **SW-281 · G · P2** — Dijital abonelik ve fiziksel ürün/hizmet ödeme yollarını mağaza kurallarına göre ayrı değerlendir.
- [ ] **SW-282 · G · P2** — Pazaryerinde gerçek sipariş isteniyorsa satıcı, stok, ödeme ve iptal durumlarını tek işlem zincirinde kur.
- [ ] **SW-283 · G · P2** — Kargo entegrasyonu gerekiyorsa takip, teslim ve iade bilgisini gerçek sağlayıcı yanıtıyla göster.
- [ ] **SW-284 · G · P2** — Satıcı/ürün şikâyeti ve anlaşmazlık çözümünü mevcut moderasyona bağla.
- [ ] **SW-285 · G · P3** — Antrenör randevusu, sponsorluk pazarı veya kamp satışı için önce dar ve ölçülebilir pilot seç.

### 30. Teknik borç, belgeler ve ürün ölçümü

Kanıt/bağlam: [docs/missing-work.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/missing-work.md>) · [docs/product/mvp-scope.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/product/mvp-scope.md>) · [.planning/STATE.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/.planning/STATE.md>) · [docs/flutter-sdk-test-cleanup.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/flutter-sdk-test-cleanup.md>).

- [ ] **SW-286 · S · P2** — missing-work listesinden tamamlanan çevrimdışı yoklama, SSS düzenleyicisi ve imzalama maddelerini güncel duruma taşı.
- [ ] **SW-287 · S · P2** — Eski MVP kapsamını canlı skor, pazaryeri, rezervasyon ve hakem motorunun bugünkü kapsamıyla güncelle.
- [ ] **SW-288 · S · P2** — .planning/STATE tarihsel 5 Ekim durumunu yeni doğrulama raporlarıyla uzlaştır.
- [ ] **SW-289 · R · P2** — Eski raporların SDK yok uyarılarını silmeden güncel test kanıtına referansla tamamla.
- [ ] **SW-290 · G · P2** — Kullanılmayan fixture/controller adaylarını gerçek referans taramasıyla ayıkla; test amaçlı olanları koru.
- [ ] **SW-291 · G · P2** — Çok büyüyen ekranları ihtiyaç halinde sunum/veri sınırlarını koruyarak küçük sorumluluklara ayır.
- [ ] **SW-292 · G · P2** — Widget'tan doğrudan backend çağrısı ve data paketine UI bağımlılığı için otomatik sınır kontrolü ekle.
- [ ] **SW-293 · G · P2** — Şema, RPC ve özellik bayrağı değişimlerinin belge/tanılama kataloğu eşliğini otomatik denetle.
- [ ] **SW-294 · G · P2** — Kulüp kurulum tamamlama, haftalık aktif kulüp ve başarılı temel işlem oranlarını kişisel veri azaltımıyla ölç.
- [ ] **SW-295 · G · P2** — Geliştirme listesini kullanıcı etkisi, bağımlılık ve doğrulanabilir bitiş ölçütüyle düzenli yeniden sırala.

### 31. Bütünleşik gerçek hesap kabul senaryoları

Kanıt/bağlam: [docs/all-roles-testing-guide.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/all-roles-testing-guide.md>) · [docs/local-test-center.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/local-test-center.md>) · [docs/product-development-roadmap.md](<C:/Users/Nisa/Desktop/SwanSpor V1.0.5/docs/product-development-roadmap.md>).

- [ ] **SW-296 · D · P0** — Yönetici program oluşturur → veli yanıtlar → antrenör yoklama kaydeder → sporcu sonucu görür zincirini gerçek hesaplarla tamamla.
- [ ] **SW-297 · D · P0** — Kimlik incelemesi → kulüp üyeliği → branş belgesi → yetkili işlem → görev iptali zincirini gerçek Auth üzerinden doğrula.
- [ ] **SW-298 · D · P0** — Resmi maç → hakem kabulü → esame → canlı olay → rapor → public sonuç → düzeltme zincirini gerçek hesaplarla tamamla.
- [ ] **SW-299 · D · P1** — Aidat tahakkuku → ödeme kaydı → düzeltme talebi → bağımsız onay → maskeli muhasebeci okuması zincirini doğrula.
- [ ] **SW-300 · D · P1** — Yerel Test Merkezi'ni güncel tam migration zinciri, gerçek Docker/GoTrue ve beş hesapla kurup rol geçişlerini doğrula.

## Önerilen uygulama sırası

1. SW-001–SW-015: başarısız test ve statik sözleşme bulgularını doğru ürün kararıyla çöz. Testi geçirmek için yetki korumasını gevşetme.
2. CI'nin tam mobil/konsol kapsamını ve aynı commit'ten yayın kapısını kur.
3. İlk beta kapsamını seç; canlı şema/istemci/bayrak eşliğini bu kapsam için doğrula.
4. Apple imzası, konum izni, ilk açılış ve fiziksel bildirim kabulünü tamamla.
5. SW-296–SW-300 bütünleşik hesap zincirlerini kabul ortamında çalıştır.
6. Seçilen P1 işletim/geri kazanım kanıtlarıyla küçük kulüp grubuna kapalı beta aç.
7. P2 işleri kullanıcı etkisiyle sırala; P3 fikirlerini ayrıca değerlendir.

Bir işi bitmiş saymak için ilgili commit, migration/bayrak durumu, hesap/rol senaryosu, beklenen/gerçek sonuç, hata/tekrar davranışı ve gerekiyorsa cihaz kabulü kaydedilir. Gerçek isim, kimlik, belge ve anahtarlar kanıt raporuna eklenmez.

Bu envanterin hazırlanması ürün kodu, canlı veritabanı, özellik bayrağı, mağaza hesabı veya dağıtımı değiştirmedi.

