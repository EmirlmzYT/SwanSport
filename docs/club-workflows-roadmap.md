# Kulüp iş akışları — 20 Ekim 2026

Mevcut uygulama ve veri yollarının denetiminden çıkan beş eksik; mevcut modüller genişletilir. Ana sayfaya yeni büyük paneller eklenmez.

| Sıra | İş | Kabul ölçütü | Durum |
| --- | --- | --- | --- |
| 1 | Duyuru okundu / onay takibi | Gerçek açılış ve açık onay ayrı; içerik değişirse eski onay geçersiz; yetkili personele toplamlar | Tamam: SQL 3/3, widget 3/3, analiz 0 hata/uyarı |
| 2 | Telefon takvimine aktarma | Mevcut etkinlikten geçerli .ics dosyası; saat/kaçış/UTF-8 testleri; açık kullanıcı eylemi | Tamam: veri 4/4, açık onay/cancel widget testi, analiz 0 hata/uyarı |
| 3 | Sezon kadro devri | Kaynak sezon/takım seçimi ve önizleme; eski kayıtlar korunarak yeni takım/hedef sezona atomik, tekrar güvenli kopya | Tamam: sezon SQL 9/9, önceki kadroyu seçip kaydetme widget testi |
| 4 | Kısmi malzeme iadesi | Miktar ve sağlam/hasarlı/kayıp ayrımı; stok tutarlılığı; tekrar ve fazla iadeye sunucu kilidi | Tamam: SQL 76/76 (2 yeni + 74 bağlı regresyon), son SQL 2/2, konsol miktar yazısı ve sınır testi |
| 5 | Resmî transfer talepleri | Taraf kapsamlı talep ve karar; yetkisiz resmî kayıt yazısı yok; mevcut resmî transfer otoritesi korunur | Tamam: SQL 6/6, ekran/yetki/tekrar/320px-büyük yazı ve iki tema görsel testi |

Her adımda ortak veri servisi → sunucu yetkisi → mevcut ekran → işlevsel test → analiz → kayıt sırası izlenir. Gerçek hesap/çocuk verisi test fixture'ına alınmaz. Yeni SQL önce izole PostgreSQL testinde çalıştırılır; canlı veritabanına uygulanmaz. İstemci yerelde yenilenir; canlı backend gerektiren adımlar migration uygulanana kadar yerelde uçtan uca canlı kabul sayılmaz.

## Sınırlar

- Okundu/onay hukuki rıza veya yoklama değildir. Sayaçlar gerçek kayıtlardır; teslim edilmeyen kişiye okunmuş kaydı üretilmez.
- Takvim aktarımı tek seferliktir; sonradan değişen/iptal edilen etkinlikler telefon takvimine otomatik eşitlenmez.
- Sezon kopyası lisans/aidat/yoklama ve eski kadroyu değiştirmez.
- Hasarlı/kayıp iade kullanılabilir stoğa eklenmez.
- Kulüp transfer talebi resmî lisans devri değildir; mevcut federasyon yetkisi son kayıt otoritesidir.

## Uygulama ve doğrulama kaydı

- Duyuru: `0134_announcement_receipts.sql`, ortak `announcement_receipts.dart`, mevcut duyuru kartının ayrıntı penceresi. Metin her değiştiğinde yeni UUID revizyonu oluşur; eski metne dönmek de eski onayı canlandırmaz. Personel yalnız toplamları görür; kişi bazlı okuma listesi açılmaz. Var olan duyuru erişimi korunur, üyeliği olmayan veliye yeni okuma yetkisi verilmez.
- Takvim: mevcut `/calendar` gün başlığına küçük aktarım simgesi, RFC 5545 UTF-8 satır katlama/kaçış/UTC/tüm-gün özel bitişi ve kalıcı kaynak UID. Dosya tarayıcıda indirilir; mobilde mevcut FilePicker kaydet akışından geçer. Özel veli sonuçları/katılımcı/sağlık alanları dışarı alınmaz. Fiziksel iOS/Android takvim uygulamasına içe aktarma ayrıca denenmelidir.
- Sezon: `0136_season_roster_sources.sql` salt okuma önizlemesi. Yeni yazıcı yoktur; seçilen aktif sporcular mevcut `open_club_season` ile yeni takım ve yeni sezona yazılır. Aynı takımın içine ikinci kopya üyelik eklenmez; eski kayıtlar korunur. Kaynak listesi son 100 sezon/takım grubudur, aktif ve hesapsız sporcular dahildir. 200 kişilik mevcut seçim sınırı korunur.
- Envanter: `0137_partial_inventory_returns.sql` özel işlem defteri ve değişmez orijinal zimmet miktarı. Kalan miktar stokta kullanılmaya devam eder; yeni sağlam iade yeniden zimmetlenebilir. Eski tam-iade RPC'si yalnız kalanı kapatır. Mobil ve konsol ortak miktar penceresini kullanır. Kısmi hasarlı/eksik kayıtlar ilgili mobil filtreden düşmez.
- Transfer: `0138_transfer_requests.sql`, `transfer_requests.dart`, `/transfer-talepleri`. Profil menüsü, Yönetim ve sportif planlama girişleri; rol hesabı SwanAccess'te, işlemler sunucuda. `transfer_requests` bayrağı **admins** başlar. Talep kaynak yöneticiden gelir; hedef kabulü ve yetişkin sporcu/gerçek veli onayı güncel ilişkilerle yeniden denetlenir. Son karar iki ilde branşın `license_registrar` yetkisini ister ve mevcut `federation_transfer_athlete` motorunu aynı işlemde çağırır. Özel append-only olay kaydı başarısızsa resmî transfer de geri alınır. Üyelik/lisans güncellemesi bu mevcut motorun sözleşmesidir; kulüp butonu aynı yetkiyi kazanmaz. Aile kendi çocuğunun adını görür; diğer taraflara güvenli referans projekte edilir. Talep doğrudan tabloya yazılamaz. Hesap/özel talep silinmesi mevcut silme akışlarını engellemez.

| Kontrol | Sonuç |
| --- | --- |
| Mobil hedefli testler (9 dosya, görseller dahil) | 40/40 |
| Ortak veri / erişim / bayrak / takvim / sezon / envanter | 57/57 |
| Konsol envanter: kapsam, dar ekran, gerçek sıfır, kısmi iade yazısı | 4/4 |
| Duyuru / sezon / kısmi iade / transfer SQL | 3 + 9 + 2 + 6 = 20/20 |
| Kısmi iadeyle birlikte çalışan önceki SQL regresyonları | 74/74 |
| Geniş Dart analizi + son değişen kaynak/test analizi | 0 hata, 0 uyarı; mevcut stil info kayıtları korunur |
| Migration söz dizimi | Sorunlu dosya 0 |
| Genel konsol testi | 80 geçti, 3 başarısız; aşağıdaki sınır geçerli |

Genel konsol koşusunda `federation_results_screen_test` (admin bypass beklentisi), `module_visibility_test` (federasyon görünürlüğü beklentisi) ve `mission_control_test` (waitlist metni bulunamaması) başarısızdır. Bu çalışma bu üç alanın davranışını değiştirmedi; tam konsol paketi yeşil olarak raporlanmaz. Hedef envanter kontrolleri ayrıca 4/4 geçti. Genel SSS aracı önceki `federation_bulletin [admins]` eşleştirme eksiğini bildirir (46 bayrak / 45 eşleşme); yeni transfer bayrağı SQL/Dart/sync/SSS/gerçek ekran kapısıyla bağlıdır.

Kanıt günlükleri ve kişisel veri içermeyen gerçek widget görselleri ignore edilen `build/quick-access-verification/workflows-*`, `transfer-light.png`, `transfer-dark.png` altındadır. Yerel geliştirme web derlemesi `apps/swansport_app/build/workflows-web` çıktısıdır; mevcut CupertinoIcons font bildirimi ayrı, derleme hatası değildir. Canlı SQL, üretim yayını, gerçek iki oturumlu PostgreSQL yarış testi ve fiziksel takvim uygulaması kabulü yapılmadı. Yeni backend akışları 0134–0138 canlıya uygulanmadan gerçek sunucuda çalışmış sayılmaz. Takvim aktarımı için backend migration gerekmese de 0135 yardımı taşır.
