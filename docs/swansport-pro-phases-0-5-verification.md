# SwanSport Pro Faz 0–5 doğrulama raporu

## 2026-11-19 açık iş takibi

### Kanıt sınıfları ve yerel altyapı

Aktif checkout `codex/pro-phases-0-5` ve başlangıç `2b6ed14` olarak yeniden
doğrulandı. Flutter 3.47.7 ve Node 24.19 hazırdır. Bu makinede `docker`
çalıştırılabilir dosyası bulunmadığı için yerel Test Merkezi başlatılamadı.
Dolayısıyla gerçek GoTrue, Storage signed URL ve RLS ile App → Pro → App zinciri;
onay, ret, dosya açma hatası, yetkisiz dosya ve eşzamanlı ikinci yönetici
senaryoları bu turda gerçek yerel sunucu kabulü sayılmamıştır. Üretime
bağlanılmadı.

### Mesleki belge görsel kanıt düzeltmesi

Önceki dört golden'da detay yakalaması Navigator overlay'ini dışarıda bırakıyor,
bu nedenle liste ile aynı görüntü üretiliyordu. `MaterialApp.builder` üstündeki
RepaintBoundary ile overlay de yakalandı. Liste ve açılmış detayın mobil/geniş
dosyaları artık dört farklı SHA-256 değerine sahiptir ve test 4/4 geçmiştir.
Bu dosyalar hâlâ Flutter testinin Ahem fontunu kullanır; gerçek-font tarayıcı
kanıtı değildir. Docker engeli nedeniyle gerçek fixture ve tarayıcı zinciri
tamamlanmış sayılmamıştır.

### Kulüp üyelik başvurusu

Genel Kulüp Yönetimi listesindeki kör kabul/ret ikonları kaldırıldı. Satır artık
başvuru sahibini, rolü, tarihi ve başvuru notunu gösteren ayrı karar detayını
açar. Ret gerekçesi istemcide zorunludur ve mevcut `p_note` sözleşmesine gider.
Antrenör kabulünde 1–5 kademe seçimi korunur; 1. kademe için mevcut
`eligible_supervisors` kaynağından sorumlu antrenör seçilmeden kabul düğmesi
açılmaz. Widget testi, detay ve boş ret gerekçesinin kapatılmasını doğruladı.

Kulüp evrakı için kaynak incelemesi gerçek açığı doğruladı: `documents` tablosu
yalnız `name/kind/size_label` metadata'sı içeriyor; Storage path, sürüm,
geçerlilik ve arşiv durumu yok. Mevcut Pro “Belge Ekle” işlemi dosya yüklemez.
App'teki kulüp onay belgeleri ise ayrı `verification_documents` ve korumalı
Storage sözleşmesini kullanır. Bu iki süreci yanlışlıkla birleştirmeden kulüp
arşivi için yeni sunucu sözleşmesi gerekir; gerçek Storage/RLS doğrulanamadığı
için bu turda sahte upload eklenmedi ve açık bırakıldı.

### Branşa özgü antrenör ölçümü

Pro komutu artık yalnız toplam puan RPC'sine bağlı değildir. Yeni dar
`submit_coach_set_metric` RPC'si açık kulüp oturumu, aktif kulüp personeli,
aktif katılımcı, set sınırı ve kilidi sunucuda doğrular; 0105'in aynı
`valid_drill_metric` sözleşmesini kullanır. Pro formu:

- geleneksel okçulukta atış dizisini `TargetScoreMetric`,
- teniste deneme adını ve başarı/hata sayaçlarını `AttemptDrillMetric`,
- yüzmede mesafe ve süreyi `LapIntervalMetric`

olarak taşır. Sporcu değişiminde bütün taslak alanlar temizlenir. Widget
testleri okçulukta stale-state korumasını, tenis ve yüzmede tipli payload'ı
doğruladı (9/9). PGlite testi üç branş payload'ının kayıtta aynen korunduğunu
doğruladı (1/1); mevcut branş regresyon paketi değişiklik öncesinde 27/27 geçti.
Yeni migration gerçek Supabase/Docker üzerinde uygulanmadığından canlı veya
yerel gerçek sunucu kabulü değildir.

### Bu turun açık işleri

- Panel, Görevler, Takvim, Gelen Kutusu ve Hesap için gerçek-font mobil/geniş
  tarayıcı kabulü ve kalan görsel düzenleme.
- Kulüp evrak arşivi için Storage path + sürüm/geçerlilik/arşiv sözleşmesi,
  RLS ve gerçek upload/preview.
- Federasyon sonuç inceleme/hakem ataması ile tesis görev hedeflerinin ayrık
  bozuk-kimlik/yetkisiz/geri dönüş kabulü.
- Yalnız gerçek Pro kabulü geçen işlerde App–Pro ana giriş/fallback geçişi.
- Docker sağlanan ortamda gerçek Auth/Storage/RLS App → Pro → App zinciri.

Bu rapor aktif `codex/pro-phases-0-5` checkout'unda kaynak incelemesi ve yerel
testlerle doğrulanan davranışları kaydeder. “Yerel doğrulandı” canlı Supabase,
gerçek imzalı dosya deposu veya fiziksel cihaz kabulü anlamına gelmez.

## Faz 1 sözleşme düzeltmesi

Faz 0 denetimi sonrası uygulanan Mesleki Belge Başvuruları akışı ikinci bir
karar servisi kullanmaz. Pro, App Onay Paneli ile aynı `reviewCredential` /
`review_credential` sözleşmesini çağırır. Pro çağrısı yalnız ek olarak
`expectedStatus: pending` gönderir; RPC satırı kilitledikten sonra beklenen
durumu karşılaştırır. Böylece eşzamanlı ikinci karar reddedilir, fakat mevcut
sonradan iptal/düzeltme davranışı yedi parametreli çağrılarda korunur.

Yerel kabul: belge widget senaryoları 9/9, Pro rota ve dört responsive golden
29/29, App rota/host 15/15, kimlik-üyelik SQL yetki zinciri 35/35 geçti.

## Faz 0 — Mesleki Belge Başvuruları

### Çalışan zincir

| Adım | Yetki/kapsam | Giriş | Sonuç | Kanıt |
| --- | --- | --- | --- | --- |
| Bekleyen liste | Platform yöneticisi | Pro Panel veya Görevler → Mesleki Belge Başvuruları | Gerçek `pendingCredentialsProvider`; boş/yükleniyor/hata ayrımı | Widget ve rota testleri |
| Detay ve belge | Platform yöneticisi + sunucu RLS | Liste satırı → Başvuru ayrıntısı | Belge türü ve korumalı HTTPS açma köprüsü; URL kart/log/bildirime yazılmaz | Widget testinde açma ve hata senaryosu |
| Onay | Platform yöneticisi | Detay → Onayla | Antrenör belgesinde kademe ve branş zorunlu; mevcut `reviewCredential` sözleşmesi | Widget + SQL testi |
| Ret | Platform yöneticisi | Detay → gerekçe → Reddet | Boş gerekçe sunucuda reddedilir; girilen gerekçe servise aktarılır | Widget + SQL testi |
| Geçmiş | Platform yöneticisi | Aynı ekranın karar geçmişi | `reviewLogProvider` ile karar izi | Kaynak incelemesi/widget render |
| Ayrı branş eşlemesi | Platform yöneticisi | Branşı eksik onaylı kayıt → Branş ata | Mevcut `setCredentialSport` sözleşmesi; yalnız onaylı antrenör belgesi | Kaynak + SQL yetki kuralı |
| Başvuran sonucu | Başvuran kullanıcı | App'in mevcut belge/hesap durumu girişleri | Aynı `profile_credentials.status`; ilgili provider invalidation | Ortak veri sözleşmesi ve SQL testi |

### Eşzamanlılık ve başarısızlık

- Karar RPC'si hedef satırı kilitler ve yalnız `pending` durumdan terminal
  duruma geçirir. İkinci yönetici “Başvuru zaten sonuçlandırıldı” hatası alır;
  istemci liste/geçmiş sağlayıcılarını yenileyerek güncel durumu gösterir.
- İşlem sürerken eylemler kilitlenir; çift dokunma ikinci servis çağrısı üretmez.
- Servis hatası başarı mesajına çevrilmez. Dosya açılamazsa kullanıcıya
  “Belge açılamadı. Tekrar deneyin.” gösterilir.

### Yerel kabul sonuçları

| Senaryo | Sonuç |
| --- | --- |
| Onay ve çift dokunma | Geçti — tek karar çağrısı |
| Gerekçeli ret | Geçti — gerekçe sözleşmeye taşındı |
| Boş liste | Geçti — açık boş durum |
| Korumalı dosya açma | Geçti — HTTPS host köprüsü |
| Dosya açma hatası | Geçti — başarı gösterilmedi, tekrar mesajı |
| Eşzamanlı/ikinci terminal karar | Geçti — SQL satır kilidi ve pending kontrolü |
| Yetkisiz ekran sorgusu | Geçti — provider çağrılmadan fail-closed |

Komut kanıtları:

- `node --test --test-name-pattern="professional review permits exactly one terminal decision" tools/identity_membership_sql_test.mjs` — geçti.
- `flutter test --no-pub test/phase4_specialist_platform_test.dart` — 9/9 geçti.
- `flutter test --no-pub test/pro_routes_contract_test.dart test/pro_tasks_action_queue_test.dart` — 25/25 geçti.
- Pro features ve Pro uygulaması `flutter analyze --no-pub --no-fatal-infos` — sorun yok.
- App `flutter test --no-pub test/pro_phase4_host_parity_test.dart` — geçti; App analizi exit 0, depoda önceden bulunan info lintleri devam ediyor.

## Faz 1 — Pro ana yüzeyleri

Kaynak incelemesi mevcut ortak Pro shell/chrome düzeninin Panel, Görevler,
Takvim, Gelen Kutusu ve Hesapta zaten kullanıldığını gösterdi. Faz 0'ın belge
kuyruğu Panel ve Görevler'e doğrudan hedef olarak eklendi; yinelenen tam kart
listesi oluşturulmadı.

| Kabul | Yerel sonuç |
| --- | --- |
| Platform yöneticisi bekleyen belgeye en kısa yoldan gider | Geçti — Panel ve Görevler doğrudan profesyonel inceleme rotası |
| Kulüp yöneticisi üyelik başvurusuna gider | Geçti — mevcut gerçek kulüp yönetimi rotası |
| Antrenör bugünkü yoklamaya/oturuma gider | Geçti — seçili kulüp ve feature flag kapsamlı görev |
| Panel kısa özet, Görevler işlenebilir liste | Geçti — kart listeleri özdeş değil testi |
| Inbox ilgili kayıt/filtreye gider | Geçti — bildirim rota beyaz listesi ve tap callback |
| Scope değişiminde eski kayıt görünmez | Geçti — workspace controller/account change testleri |
| Dar ve geniş yerleşim | Geçti — 320×568–1440×900, 1.0×–2.0× cihaz matrisi |

Komutlar: Pro görev/takvim/cihaz matrisi 51 davranış testi geçti; iki yanlış
dosya adı komut yükleme hatası olarak kaydedildi ve gerçek shell/inbox/workspace
testleriyle tekrarlandı (39 + 6 test geçti). Ürün davranışı hatası oluşmadı.

## Faz 2 — Kulüp ve antrenman operasyonları

Mevcut Pro kulüp yönetimi; üyelik başvurusu, duyuru ve kulüp evrakını ayrı
bölümlerde gerçek provider'larla sunuyordu. Takım/kadro, yoklama, geçmiş ve
sonuç zincirleri de mevcut ortak Pro feature testlerinde geçti.

Bu fazda bulunan gerçek eksik, kulüp oturumunda antrenörün farklı
katılımcıların ölçümünü Pro'dan yazamamasıydı. Oturum ekranına açık katılımcı
seçimi ve basit set toplamı girişi eklendi. Sporcu değişince kaydedilmemiş alan
temizleniyor. Sunucuda yeni dar RPC şu kontrolleri tekrar yapıyor: kulüp
oturumu ve açık durum, aktif kulüp personeli, aktif oturum katılımcısı,
protokol/set/toplam sınırı ve kilitsiz set.

| Kabul | Yerel sonuç |
| --- | --- |
| Üyelik liste→işlem→sonuç | Geçti — mevcut kulüp yönetimi testi |
| Kulüp evrakı ayrı işlem | Geçti — ayrı belge provider/bölümü |
| Kadro/takım ve hesapsız sporcu sözleşmesi | Geçti — typed roster bağlamı; nullable profile sözleşmesi değiştirilmedi |
| Yoklama yazma ve geçmiş | Geçti — rol/flag, kayıt ve boş/hata durum testleri |
| İki branşlı seçim | Geçti — takım sportCode ve App branş takım filtresi |
| Farklı sporcuların ölçümü | Geçti — katılımcı seçimi, stale input temizliği ve staff-only SQL testi |
| Kilitleme ve sonuç | Geçti — sonuç review/lock testi |
| App bireysel/kulüp geçmiş ayrımı ve veli sonucu | Geçti — App training/context/guardian testleri |

Yeni dar RPC yalnız mevcut Pro arayüzünün sunduğu basit toplam modelini kabul
eder. Ayrıntılı ve branşa özgü archetype ölçümleri yanlış biçime indirgenmez;
bu protokollerde açık hata verir. Bu, sahte sonuç üretmek yerine kaydedilmiş
model sınırını koruyan bilinçli bir kısıttır.

## Faz 3 — Veli, finans, tesis, hakemlik ve federasyon

Faz 0 matrisi sırasıyla yeniden yürütüldü. Kaynakta bu modüllerin ana işlem
adımları daha önce tamamlanmış olduğundan, kanıtlanmamış yeni özellik
eklenmedi; gerçek işlemler ve yetki sınırları mevcut testlerle yeniden kabul
edildi.

| Modül | Ana Pro işlemi | Yetki/kapsam kanıtı | Sonuç |
| --- | --- | --- | --- |
| Veli bağlantıları | Davet oluşturma, gerçek bekleyen davet, iptal ve maskeli bağlı hesap | Kulüp yöneticisi; kimliği doğrulanmış veli tüketir | Pro 3 test + veri sözleşmesi geçti |
| Aidat/muhasebe | İsimli aidat yönetimi; maskeli defter, taahhüt ve mutabakat | İsim kulüp admin; muhasebeci yalnız yetkili kulüp ve `athlete_ref` | Pro/feature testleri geçti |
| Tesis | Doluluk, görev, rezervasyon ve çakışma yönetimi | Tesis yönetici/delege veya kulüp staff; scope değişimi state temizler | Feature 31 ilgili davranış + SQL geçti |
| Hakemlik | Atama yanıtı, esame, canlı olay, rapor | Kabul edilmiş aktif branş hakemi/kurul kapsamı | Fail-closed, idempotent retry ve immutable rapor geçti |
| Federasyon | Atama, disiplin, resmî tesis ve yayımlama operasyonları | Başkan/MHK/kurul/il kapsamları ayrık | Workspace/panel ve SQL yetki zinciri geçti |

Toplu Pro features çalıştırması 69/69 geçti. SQL toplu komutunda Faz 0'ın ilk
strict karar uygulaması iki eski C1 yeniden-inceleme senaryosunu bozdu; bu
gerçek regresyon teşhis edildi. Çözüm olarak mevcut `review_credential`
yeniden-inceleme sözleşmesi korundu ve Pro bekleyen kuyruğu ayrı
mevcut `review_credential` RPC'sinin opsiyonel `p_expected_status` kapısına
alındı. İlgili üç SQL senaryosu tekrar
çalıştırıldı ve geçti.

## Faz 4 — App/Pro görev ayrımı

Son parite matrisi App'teki eski rota, görünür kısayol, bildirim hedefi ve
kullanıcı sonucuyla karşılaştırıldı. Profesyonel mutasyonlar Pro'nun normal
menülerindedir; App sosyal menüsü aynı operasyon kataloğunu yinelemez. Buna
karşılık App şu doğal girişleri korur: doğrulama başvurusu ve durum, belgeler,
aidatlarım, bireysel antrenman/katılım/geçmiş ve sporcu-veli sonuçları.

Legacy profesyonel rotalar silinmedi. Registry ve navigation bridge eski
bildirim/deep link'i çözer; ortak feature host aynı SwanAccess ve feature flag
kapılarını uygular. Böylece Pro hedefi kullanılamadığında kullanıcı çalışan
uyumluluk yolunda açık hata/rol kapısı görür, boş route görmez.

Yerel kanıt: navigation, legacy registry/bridge, route-link adapter, birleşik
rotalar, bildirim yönlendirmesi, ortak host paritesi ve training App deneyimi
toplam 31/31 geçti.

## Faz 5

### Son rol zincirleri

1. Başvuran App'in `/dogrulama` girişinden belge sürecini başlatır ve kendi
   `profile_credentials` durumunu okur.
2. Platform yöneticisi Pro Panel/Görevler'den “Mesleki Belge Başvuruları”na
   gider; belgeyi korumalı bağlantıyla açar ve mevcut karar RPC'sinin
   `expectedStatus: pending` kontrolüyle karar
   verir.
3. Aynı satır/provider sözleşmesi App'te güncel sonucu gösterir. Yetkisiz Pro
   hesabı provider sorgusu yapmadan kapanır; storage ve karar yetkisi sunucuda
   yeniden uygulanır.
4. Antrenör Pro'da kulüp, branş/protokol ve oturum katılımcısını seçip ölçümü
   kaydeder. Sporcu App'ten katılım/bireysel geçmişini, yetkili veli yalnız
   açıkça paylaşılan sonucu görür.

### Son test özeti

| Katman | Son çalıştırma |
| --- | --- |
| Mesleki belge + Pro training widget | 16/16 geçti; Pro features analyze temiz |
| Pro route/görev/görsel | 27/27 geçti; Pro analyze temiz |
| Training veri modeli | 35/35 geçti; data analyze exit 0, depodaki mevcut 889 info lint sürüyor |
| Kimlik/üyelik SQL zinciri | 35/35 geçti |
| Branş/antrenman SQL zinciri | 27/27 geçti |
| App host/navigation/notification son koşusu | 18/18 geçti |
| Faz 1 cihaz matrisi | 51 davranış geçti; 320×568–1440×900 ve 1.0×–2.0× |
| Faz 3 modül yüzeyleri | 69/69 geçti |
| Biçim/diff | `dart format --set-exit-if-changed` ve `git diff --check` temiz |

### Görsel kanıt

- Mobil 390×844: `apps/swansport_pro/test/goldens/professional_review_mobile.png`
- Geniş web 1440×900: `apps/swansport_pro/test/goldens/professional_review_wide.png`
- Mobil detay 390×844: `apps/swansport_pro/test/goldens/professional_review_detail_mobile.png`
- Geniş detay 1440×900: `apps/swansport_pro/test/goldens/professional_review_detail_wide.png`

Bu dosyalar deterministik Flutter render goldens'tır; otomatik testte yeniden
karşılaştırıldı. Flutter test ortamı metni Ahem blok glifleriyle rasterladığı
için hizalama, yüzey, ayrım ve overflow kanıtıdır; gerçek font/canvas cihaz
ekran görüntüsü değildir.

### Değişen alanlar

- `swansport_data`: korumalı belge/karar provider'ları, mevcut karar servisinin
  opsiyonel pending beklentisi ve antrenör-katılımcı ölçüm komutu.
- `swansport_pro_features`: çalışan belge liste/detay/karar/geçmiş/branş
  eşleme ekranı; Pro antrenör katılımcı ölçümü.
- `swansport_pro`: Panel/Görevler doğrudan hedefleri, korumalı dosya host
  köprüsü ve responsive golden kabul.
- `swansport_app`: aynı korumalı dosya host sözleşmesi; mevcut öz-servis ve
  legacy rotalar korunmuştur.
- Supabase: mevcut karar RPC'sinde opsiyonel pending kontrolü ve dar staff
  ölçüm RPC'si.
- Dokümantasyon/testler: parite matrisi, bu rapor, PGlite ve widget senaryoları.

### Doğrulanmayan sınırlar

- Migration'lar canlı Supabase projesine uygulanmadı.
- Gerçek storage signed URL, tarayıcı pop-up politikası, gerçek App↔Pro oturum
  geçişi ve push teslimi canlı ortamda denenmedi.
- Fiziksel Android/iOS cihaz, gerçek ekran okuyucu ve gerçek fontlu manuel
  görsel kabul yapılmadı.
- Yeni antrenör ölçüm girişi basit toplam protokollerini kapsar; ayrıntılı ve
  branşa özgü archetype ölçümleri yanlış biçimde sadeleştirilmek yerine sunucu
  tarafından reddedilir.

## 2026-11-19 açık iş tamamlama turu

Bu bölüm önceki kabul raporunun üzerine yapılan son uygulama ve yeniden kabul
turudur. Üretime bağlanılmadı, uzak migration veya deploy yapılmadı.

| Madde | Uygulanan değişiklik | Yerel doğrulama | Kabul durumu / somut sınır |
| --- | --- | --- | --- |
| 1. Beş ana Pro yüzeyi | Gelen Kutusu ortak `ProOperationsFeatureHost` kabuğuna alındı; Panel öncelikli işi, ortak başlık/durum/boş-hata düzeni ve mevcut responsive yüzeyler korundu. Görsel fixture giriş noktası yalnız yerel kabul için eklendi. | Pro analyze temiz; rota/shell/golden/accessibility/cihaz matrisi 98/98 geçti. Edge'de gerçek fontla Panel, Görevler, Takvim, Gelen Kutusu ve Hesap 1440×900 açıldı. | **Açık:** Edge viewport 390×844'e canlı küçültülünce Flutter web motoru `Trying to render a disposed EngineFlutterView` verip boş canvas çizdi. 390×844 widget/golden geçti fakat bu gerçek mobil tarayıcı kabulü değildir. |
| 2. Görev hedefleri | Üyelik kartı `?tab=applications` ile başvuru sekmesine; federasyon sonuç ve hakem işleri ayrı rotalara; tesis kartı `?duty=<id>` ile ilgili kayda bağlandı. Tesis kaydı kayıp/kapsam dışıysa güvenli açıklama gösteriliyor. | Pro rota/shell/bildirim/kulüp testleri toplu koşuda geçti; facility feature 15/15 geçti. | **Yerel kaynak+widget kabulü geçti.** Gerçek oturumlu tarayıcı deep-link kabulü yerel Auth olmadığı için ayrıca doğrulanmadı. |
| 3. Kulüp evrak arşivi | Eski metadata korunarak private `club-documents` bucket sözleşmesi, `storage_path`, sürüm, geçerlilik, arşiv zamanı ve yükleyen alanları eklendi. Pro PDF/JPEG/PNG yükler, beş dakikalık imzalı önizleme açar ve fiziksel silme yerine arşivler. Dosya okuma kulüp personeline daraltıldı. | PGlite migration/policy 1/1; veri modeli 2/2; Pro kulüp ekranı 5/5 geçti. | **Açık:** Docker/Supabase yerel servisi bulunmadığı için gerçek Storage upload/signed URL/RLS kabulü yapılmadı. |
| 4. Branşa özel ölçümler | Mevcut branch engine'in yedi archetype'ı (`target_score`, `attempt_drill`, `lap_interval`, `combat_rally`, `strength_set`, `routine_judge`, `mind_tactical`) typed payload ile bağlandı. Branş/sporcu değişiminde tüm taslak alanlar temizleniyor. | Feature training 13/13; veri 37/37; SQL toplu 64/64; App geçmiş/veli/navigation 38/38 geçti. Okçuluk, tenis, yüzme ve kalan dört archetype ayrı fixture ile doğrulandı. | **Yerel sözleşme/widget/SQL kabulü geçti.** Fiziksel cihaz veya canlı Supabase sonucu değildir. |
| 5. App → Pro → App | App'in çalışan `/dogrulama` ve `/onay-paneli` yolları kaldırılmadı; Pro mevcut ortak karar servisi/RLS sözleşmesini kullanmaya devam ediyor. Yalnız Pro'da doğrulanan hedefler ayrıştırıldı; kanıtsız yeni uygulamalar arası link icat edilmedi. | Belge liste/detay goldens; geniş Edge etkileşimi; kimlik/üyelik SQL içinde tek terminal karar; App regression 38/38 geçti. | **Açık:** makinede Docker CLI/daemon olmadığı için gerçek GoTrue Auth + Storage ile App yükleme → Pro signed preview/karar → App durum zinciri, yetkisiz dosya erişimi ve iki gerçek yönetici eşzamanlılığı çalıştırılamadı. Bu nedenle App yönetim girişi korunuyor ve Pro ana girişe kesin geçiş yapılmadı. |

### Son komut kanıtı

- `apps/swansport_pro`: analyze temiz; seçili rota, shell, notification,
  kulüp, belge golden, accessibility ve cihaz matrisi **98/98**.
- `packages/swansport_pro_features`: analyze temiz; training **13/13**,
  facility **15/15**.
- `packages/swansport_data`: archive + training **37/37**. Tüm paket analizi
  exit 0; depoda önceden bulunan info lintleri devam ediyor.
- SQL/PGlite toplu: archive + kimlik/üyelik + antrenman **64/64**.
- App regression: verification/navigation/training context/guardian **38/38**.

### Görsel kabul notu

Gerçek Edge geniş ekran görüntüleri yerel `main_visual_acceptance.dart` fixture
girişiyle, üretim rotası ve yetkisi değiştirilmeden alındı. Beş ana yüzey ile
Mesleki Belge Başvuruları listesi ve açılmış detay gerçek fontla gözlendi.
Mobil görsel kanıt olarak güncel 390×844 liste/detay golden dosyaları vardır;
ancak yukarıdaki web motoru resize hatası nedeniyle bunlar gerçek tarayıcı
kanıtı olarak sınıflandırılmamıştır.

## 2026-11-19 devam turu — açık maddeler

| Alan | Uygulama | Gerçek deneme | Durum |
| --- | --- | --- | --- |
| Pro ana yüzey tasarımı | Gelen Kutusu da Panel/Görevler/Takvim/Hesap ile aynı `ProPageHeader`, 20 px içerik kenarı, ortak ikon yüzeyi ve ayrı boş/hata durumuna taşındı. | Edge'de gerçek fontla 492×792 dar içerik alanında ve 1416×760 geniş içerik alanında beş yüzey açıldı. Dar pencere ilk olarak `about:blank` iken oluşturulup boyutlandırıldı, sonra sayfa yüklendi. Panel ilk yüklemede temiz çizildi; diğer sayfalar debug web-server tek-client hot-restart ile ayrı ayrı yakalandı. | **Geçti (görsel)**. Debug hot restart sırasında `EngineFlutterView`/diagnostics hatası tekrar üretildi; ilk dar yüklemede oluşmadığı için ürün responsive düzeninden değil debug motorunun view yaşam döngüsünden kaynaklandığı belirlendi. |
| App → Pro giriş ve fallback | App Onay Paneline `SwanSport Pro’da aç` kartı eklendi; doğrudan `#/operasyon/platform-profesyonel-inceleme` hedefleniyor. URL açılamazsa App paneli kapanmıyor ve açık fallback mesajı gösteriyor. Pro login ve yetkisiz erişim ekranlarına `SwanSport App’e dön` eklendi. | 390×844 widget testinde doğru URL, başarısız launch, App panelinin korunması ve taşmasız yerleşim doğrulandı. Pro auth testleri girişsiz/yetkisiz dönüş düğmesini doğruladı. | **Yerel widget kabulü geçti.** Üretim URL'sine bağlanılmadı; kurulu native Pro tespiti için projede mevcut bir uygulama şeması bulunmadığından mevcut HTTPS bağlantı altyapısı kullanıldı. |
| Yerel Test Merkezi | Windows PATH, servisler, bilinen Docker/Podman/Rancher yolları ve WSL Ubuntu kontrol edildi. | `node tools/start_local_test_center.mjs --backend-only` güvenli biçimde `Docker Desktop` eksikliğiyle durdu. Windows ve WSL'de Docker/Podman/nerdctl ve Docker socket yok. | **Açık / altyapı engeli.** GoTrue Auth, gerçek Storage signed URL/RLS, iki yönetici eşzamanlılığı, kulüp evrak yükleme ve gerçek antrenör→sporcu→veli oturum zinciri çalıştırılamadı. Üretime veya uzak Supabase'e bağlanılmadı. |

Görsel debug notu: `flutter run -d web-server` tek bağlı tarayıcı görünümüyle
hot restart yapılırken dispose edilmiş engine view'a frame gönderme hatası
üretebiliyor. Dar pencereyi sayfa yüklenmeden önce oluşturmak ilk yükleme
problemini kaldırdı; ürün sayfalarında overflow veya breakpoint hatası görülmedi.

Son cihaz matrisi turunda yeni Gelen Kutusu başlığının 320×568 görünümünde
1.0×–2.0× yazı ölçeğinde oluşturduğu taşma ayrıca yakalandı. Kısa yükseklikte
başlık okunabilir kompakt biçime geçecek şekilde düzeltildi; matris yeniden
çalıştırıldığında 46/46 senaryo geçti.

## 2026-11-22 son yerel tarayıcı kabulü

Bu tur üretime bağlanmadan Yerel Test Merkezi (`127.0.0.1:55421`), App
(`127.0.0.1:55430`) ve Pro (`127.0.0.1:55432`) ile yürütüldü.
`build/pro-final-local-acceptance.json` içindeki dört başarılı gerçek
Auth/Storage/RLS API zinciri yeniden çalıştırılmadan mevcut sunucu kanıtı
olarak kabul edildi (`production_contact: false`). Tarayıcı kabulünde hedef
URL elle açılmadı; aşağıdaki girişler uygulamanın kendi düğmelerinden tıklandı.

| Rol | Tıklanan giriş | Açılan ekran | Gerçek tarayıcı sonucu |
| --- | --- | --- | --- |
| Platform yöneticisi (`kulup-yoneticisi@test.swansport.invalid`) | App Profil → Yönetim → Ayarlar → Onay Paneli → **SwanSport Pro’da aç** | Giriş sonrasında Pro **Mesleki Belge Başvuruları** | Yerel Pro hedefi korundu; üç bekleyen başvuru görüldü. Adı boş fixture'ın App panelini çökerttiği `Unexpected null value` hatası düzeltildi ve aynı normal girişten tekrar geçti. |
| Kulüp yöneticisi | Pro Panel/Görevler → **Bekleyen Başvurular / İncele** | Kulüp Yönetimi → Başvurular → başvuru detayı | Sentetik sporcu başvurusu, mesaj, karar notu ve gerekçeli ret alanı açıldı. Genel Kulüp Yönetimi ana sayfasında bırakılmadı. |
| Federasyon yetkilisi | Pro Görevler → **Müsabaka Sonuç İncelemesi / İncele** | Resmî Müsabakalar & Takvim | `[TEST] Tarayıcı Tenis Ligi` kaydı görünür oldu. |
| Federasyon yetkilisi | Pro Görevler → **Hakem Atamaları / Atamaları Aç** | MHK Hakem Atamaları | Aynı sentetik maç ayrı atama işlemiyle ve `Hakem Ata / Güncelle` eylemiyle açıldı; sonuç incelemesiyle birleştirilmedi. |
| Tesis yöneticisi | Pro Görevler → `[TEST] Rol Test Sahası` → **İncele** | Saha Görevleri & Yetkilendirme | İlk denemede kart görev kimliğini taşısa da aktif tesis kapsamını değiştirmediği için yetkisiz ekranı, düzeltme sonrasında ise tam olarak `77770000-0000-4000-8000-000000000001` görevini açtı. İlk açılıştaki yetki sağlayıcısı geçersizleştirme döngüsü de ayrıştırıldı; ekran aktif görev kartıyla tamamlandı. |
| Yetkisiz standart hesap (`taraftar@test.swansport.invalid`) | App Onay Paneli → **SwanSport Pro’da aç** | Pro **Profesyonel Erişim Bulunamadı** | Belge listesi/verisi gösterilmedi. **SwanSport App’e dön** yerel `127.0.0.1:55430` hedefini açtı. |
| Platform yöneticisi, Pro kapalı | App Onay Paneli → **SwanSport Pro’da aç** | Bağlantı kurulamadı | Pro web sunucusu durdurulduktan sonra yeni hedef açılamadı; özgün App sekmesi Onay Panelinde kaldı ve Bekleyen/Kişiler/Geçmiş kontrolleri kullanılabilir olmaya devam etti. |

### Bu turda bulunan ve kapatılan hatalar

- App Onay Paneli bekleyen credential sahibinin adı `null` olduğunda zorunlu
  unwrap yapıyordu. Güvenli `Kişi` fallback'i ve widget regresyonu eklendi.
- App'in Yerel Test Merkezi Pro geçişi üretim hostu yerine doğrudan yerel
  belge inceleme rotasına bağlandı; üretim hedefi release davranışında kaldı.
- Pro tesis görev kartı görev ID'sini taşıyor fakat ilgili `fieldId` kapsamını
  seçmiyordu. Kart artık kapsamı önce değiştirip sonraki frame'de hedef görevi
  açıyor; iki tesisli regresyon testi doğru kapsama geçişi doğruluyor.
- Tesis görev ekranı ilk mount sırasında `delegatedTurfFieldIdsProvider`ı
  geçersizleştirerek erişim kapısı ile sonsuz yükleme döngüsü oluşturuyordu.
  Liste yenilemesi ile gerçekten yetki değiştiren kabul/geri-alma yenilemesi
  ayrıldı.
- Pro Hesap ekranındaki ayrı **SwanSport'u Aç** düğmesi debug ortamında
  üretim adresine gidiyordu. Login/yetkisiz dönüş düğmesiyle aynı enjekte
  edilebilir yerel/release hedef sözleşmesine alındı.

### Kanıtların ayrımı

| Kanıt türü | Sonuç |
| --- | --- |
| Gerçek yerel API | `build/pro-final-local-acceptance.json`: belge onay/ret/eşzamanlı karar ve yetkisiz dosya; kulüp evrak yükleme/önizleme/arşiv/cross-club ret; çok branşlı ölçüm ve sporcu/veli görünürlüğü olmak üzere **4/4 geçti**. |
| Gerçek tarayıcı | App→Pro login sonrası hedef, yetkisiz kapı, Pro→App yerel dönüş, Pro kapalı fallback, üyelik, sonuç, atama ve tesis kartları normal kullanıcı girişlerinden tıklanarak doğrulandı. Geniş gerçek-font ekran yakalamaları bu turda App Onay Paneli, Pro belge listesi, üyelik detayı, federasyon görevleri, tesis listesi/detayı ve yetkisiz ekran için alındı. |
| Widget | App geçiş/null-ad regresyonu **3/3**; Pro auth/route/account seçkisi **40/40**; facility feature **15/15** geçti. |
| SQL | Bu tur tekrar koşturulmadı; dört yerel API kabulü gerçek GoTrue/Storage/RLS kanıtıdır. Önceki PGlite/SQL sonuçları değişmeden korunmuştur. |

Önceki dar ve geniş beş ana Pro yüzeyi kanıtları ile belge liste/detay
golden'ları görünümü etkileyen yeni bir değişiklik olmadığı için geçerlidir:

- `apps/swansport_pro/test/goldens/professional_review_mobile.png`
- `apps/swansport_pro/test/goldens/professional_review_wide.png`
- `apps/swansport_pro/test/goldens/professional_review_detail_mobile.png`
- `apps/swansport_pro/test/goldens/professional_review_detail_wide.png`

### Kalan sınırlar

- Üretim, uzak migration/deploy ve canlı hesaplarla hiçbir işlem yapılmadı.
- Bu tur gerçek tarayıcı geniş görünüm kabulüdür; önceki dar ilk-yükleme ve
  widget/golden kanıtı kullanılmış, fiziksel Android/iOS cihaz kabulü
  yapılmamıştır.
- Tarayıcıda eksik tesis hedefi, aynı güvenli “bulunamadı veya bu kapsamda
  erişilemiyor” görünümü için widget sözleşmesiyle kanıtlıdır; sentetik kaydı
  silerek ayrıca veri mutasyonu yapılmadı.

## Son teslim kanıt kaynağı ve yeniden koşulan kontroller

Bu teslim, `codex/pro-phases-0-5` dalındaki yerel commit ve entegrasyon
hazırlığıyla sınırlıdır. Ana dala merge, push, uzak migration ve deploy
yapılmamıştır.

### Önceki kabulden devralınan kanıt

- `build/pro-final-local-acceptance.json` içindeki dört gerçek yerel
  Auth/Storage/RLS zinciri: belge onay-ret/eşzamanlı karar/yetkisiz dosya,
  kulüp evrak yükleme-önizleme-arşiv/cross-club ret ve çok branşlı
  antrenör-sporcu-veli görünürlüğü. Dosya `status: passed`, dört kontrol
  `passed` ve `production_contact: false` kaydeder.
- 22 Kasım gerçek tarayıcı kabulü: App Onay Paneli → Pro belge listesi,
  login sonrası hedef koruma, yetkisiz kapı, Pro→App dönüşü, Pro kapalı
  fallback; kulüp başvurusu, federasyon sonuç, hakem atama ve tesis görev
  kartlarının normal kullanıcı girişlerinden açılması.
- Önceki dar/geniş gerçek-font ana yüzey görüntüleri ve belge liste/detay
  golden karşılaştırmaları.

### Son teslim turunda yeniden koşulanlar

- App geçiş ve `null` kişi adı regresyonu: `pro_management_transition_test`
  **3/3 geçti**.
- Pro auth, hesap ve görev/rota sözleşmeleri: seçili üç dosyada **40/40
  geçti**; son tam Pro paketi koşusu **218/218 geçti**.
- Tesis görev kapsamı ve yenileme davranışları: `facility_operations_test`
  **15/15 geçti**; ortak Pro feature paketinin tamamı **154/154 geçti**.
- Ortak veri paketinin tamamı **543/543**, yerel launcher ve ilgili
  migration/PGlite zinciri **80/80 geçti**.
- `apps/swansport_pro` ve `packages/swansport_pro_features` analizleri hata
  vermedi. App genel analizi derleme hatası vermedi; depoda önceden bulunan
  **4522 info lint** devam ediyor ve temiz analiz olarak sınıflandırılmadı.
- `dart format`, `git diff --check`, yerel araç hedef denetimi, normal
  `main_development.dart` / `main_production.dart` girişleri ve CI'ın açıkça
  `main_production.dart` kullanması yeniden doğrulandı.
- Pro üretim web girişi ve ayrı `main_visual_acceptance.dart` fixture girişi
  release modunda başarıyla derlendi. Yalnız mevcut CupertinoIcons font
  uyarısı görüldü; derleme çıkışları başarılıdır.
- Migration sırası `20261119090000` → `20261119100000` →
  `20261119113000` → `20261119120000` → `20261121163109` →
  `20261121163354` → `20261121163636` olarak doğrulandı.

### Teslim dışında kalan ayrı adımlar

- Fiziksel Android/iOS cihaz kabulü yapılmadı; ayrı UAT adımıdır.
- Üretim yayını, canlı migration, imzalı mağaza paketi, push ve canlı hesap
  kabulü yapılmadı; ayrı yayın/deploy yetkisi gerektirir.
