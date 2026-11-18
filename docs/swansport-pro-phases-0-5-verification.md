# SwanSport Pro Faz 0–5 doğrulama raporu

Bu rapor aktif `codex/pro-phases-0-5` checkout'unda kaynak incelemesi ve yerel
testlerle doğrulanan davranışları kaydeder. “Yerel doğrulandı” canlı Supabase,
gerçek imzalı dosya deposu veya fiziksel cihaz kabulü anlamına gelmez.

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
`review_pending_credential` kapısına alındı. İlgili üç SQL senaryosu tekrar
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
   gider; belgeyi korumalı bağlantıyla açar ve strict pending RPC ile karar
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

Bu dosyalar deterministik Flutter render goldens'tır; otomatik testte yeniden
karşılaştırıldı. Flutter test ortamı metni Ahem blok glifleriyle rasterladığı
için hizalama, yüzey, ayrım ve overflow kanıtıdır; gerçek font/canvas cihaz
ekran görüntüsü değildir.

### Değişen alanlar

- `swansport_data`: korumalı belge/karar provider'ları, strict pending karar
  servisi ve antrenör-katılımcı ölçüm komutu.
- `swansport_pro_features`: çalışan belge liste/detay/karar/geçmiş/branş
  eşleme ekranı; Pro antrenör katılımcı ölçümü.
- `swansport_pro`: Panel/Görevler doğrudan hedefleri, korumalı dosya host
  köprüsü ve responsive golden kabul.
- `swansport_app`: aynı korumalı dosya host sözleşmesi; mevcut öz-servis ve
  legacy rotalar korunmuştur.
- Supabase: strict pending karar wrapper'ı ve dar staff ölçüm RPC'si.
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
