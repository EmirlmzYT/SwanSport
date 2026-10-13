# Faz 4 — Federasyon konsolu ve 0113 motoru

2026-10-13. Yerel geliştirme; canlı migration/yayın/commit/push yapılmadı.

## Uygulanan kapsam

- `/mhk-atamalar`: resmi maç tablosu, Türkiye saati haftalık filtre, sunucu araması/sayfalaması, il filtresi, görev/durum rozetleri, branşlı aktif hakem seçimi ve gerçek son tamamlanan maç tarihi. Atama Başkan veya MHK için; il temsilcisi salt okunur. İmzalı rapor MHK/Başkan tarafından maç ayrıntısında okunur.
- `/il-ligleri`: yetkili federasyon/il fikstürü, durum ve tesis uygunluğu. `ConsoleTable`, `StatusPill`, `ConsoleTheme`/`ConsoleDensity`; doğrudan ekranlarda da 900px koruması.
- `/disiplin-kurulu`: en eski imzalı rapor önce, maskeli sporcu referansları, geri alınmamış kırmızı kartlar, gerekçeli karar ve karar geçmişi. Kırmızı kart veya rapor notu otomatik ceza değildir. Raporlar inceleme kuyruğudur; ayrı bir hukuki sevk/tebligat iş akışı olarak sunulmaz.
- Ortak saf domain modelleri/servis/provider'lar `federation_console.dart`; oturum bağımlılığı ve aktif okumalarda 30 saniyelik yenileme. Widget sorguları yok.
- `SwanAccess` aktif rol ve modül yetkilerinin tek istemci kaynağıdır. Yeni roller eski `resultPublisher` görevini veya resmi sonuç yazma yetkisini açmaz. `ConsoleModule.accessCheck` modül başına sınırı hem sidebar hem router için korur.

## Sunucu güvenliği

0113 ilk satırı `set local lock_timeout = '15s';`. Tek dosya işlemi ve yeniden uygulama testi kullanıldı.

`_console_federation_scope` federasyonun branşı, aktif tarih aralığı, iptal ve il kapsamını birlikte denetler. Platform yöneticiliği/muhasebecilik tek başına resmi yetki değildir. Başkan yalnız kendi federasyonunda tüm illeri görür.

`_sports_assignment_read` ham özel atama satırlarını Başkan/MHK ile sınırlar; hakem mevcut politikayla kendi satırını okumaya devam eder. İl temsilcisinin özel ret gerekçesi hem ham RLS yolunda hem JSON projeksiyonunda kapalıdır. `accepted_match_officials` genel name/duty sözleşmesi değiştirilmedi.

`assign_match_official` aynı branşta aktif hakem lisansı, açık/kilitsiz maç ve aktif Başkan/MHK rolü arar; atama ve audit atomiktir. Aynı maçta iki aktif görev yasaktır. Aynı hakem/görev zaten assigned/accepted ise tekrar audit üretmez. Görevli değişimi bildirim üretir; özel mazeret nota/push'a taşınmaz. Aynı slotun değiştirilmesi geçmişteki satırı yeniler; değişim actor/UUID/görev bilgisi audit'tedir, ayrı tarihsel atama tablosu yoktur.

`federation_disciplinary_reports` ve `federation_locked_match_report` yalnız Başkan/MHK/Disiplin Kuruluna özel rapor döndürür. İl temsilcisi, başka branş, muhasebeci ve platform admin kendi başına okuyamaz. TC/telefon/teşhis/name snapshot eklenmedi; disiplin seçiminde `athlete_ref` kullanılır.

`disciplinary_decisions` istemciye ham tablo okuma/yazma vermez. Yalnız Başkan/Disiplin Kurulu imzalı raporun donmuş esamesindeki sporcu için karar kaydeder. Operation UUID + aynı payload tekrarı aynı ID'yi döndürür; farklı payload reddedilir. Karar ve audit atomiktir; geçmiş değiştirilemez, actor hesabının FK üzerinden silinmesi notları/kaydı değiştirmez.

- Maç men: 1–10. Karardan sonra başlayan ve tescil edilen aynı branş/eski kulüp maçları, sporcu kilitli kadroda değilse cezadan düşer. Gelecekteki tarihli veya imzasız maç sayılmaz. Bu MVP'de ceza sayacı karar anındaki kulübe bağlıdır; transfer ve federasyona özgü infaz/itiraz kuralları ayrıca tasarlanmalıdır.
- Hak mahrumiyeti: 1–12 takvim ayı, sunucu zamanı ile sona erer.
- İhtar/para cezası: esameyi kilitlemez. Para cezası bu karar defterindedir; `expenses`/aidat defterine otomatik tahakkuk veya ödeme üretilmez.
- `_sports_roster_validate` içindeki kontrol doğrudan `referee_verify_lineup` yolundadır. Aday kartında `suspended` görünür; yeni oyuncu değişikliğinde de kontrol edilir. Klinik/idari durumlar veya athletes alanı elle değiştirilmez.
- Karar ve yeni esame/olay/rapor yazıları, mevcut maç kilidinden önce ortak advisory kilidi alır. Gerçek iki PostgreSQL oturumuyla yarış/deadlock testi yapılmadı; küresel MVP kilidinin yük etkisi üretimde ölçülmelidir.
- Önceden kilitlenmiş esame immutable kalır; karar geçmiş kadroyu yeniden yazmaz. Önceden kilitli bir gelecek maçın yeniden onay/değişiklik ve resmi federasyon düzeltme süreci ayrı iş akışıdır.

## Tesis sözleşmesi

Resmi maçın `events` içine kopyalanmasını engelleyen mevcut guard korunur. `official_match_facilities` yalnız maç–tesis/saat tahsis bağlantısıdır, ikinci maç tablosu değildir. `allocate_official_match_facility` yalnız tesis sahibi katılımcı kulübün aktif personelinden kayıt kabul eder; Başkan etiketi başka kulübün tesisini tahsis hakkı vermez. Bu RPC konsolun bu fazdaki görüntüleme ekranından yazma aksiyonuna bağlanmadı.

Çakışma yalnız aynı tesis UUID'sindeki gerçek etkinlikler, aktif rezervasyonlar ve başka resmi tahsislerin aralıklarından hesaplanır. Özel rezervasyon başlığı/kişi/telefonu dönmez. Kesin süre/tahsis yoksa null = “Doğrulanamıyor”; sıfır uydurulmaz. Bu görünüm bir rezervasyon kilidi değildir; başka kulüp takvimi/rezervasyon yazılarıyla çapraz işlem yarışını engellediği iddia edilmez.

## Açık kapsam / doğrulama sınırları

- Resmi raporda tipli, donmuş antrenör sevki bulunmuyor. Bu fazdaki ceza formu yalnız sporcu seçer; antrenör hedefi, itiraz/karar revizyonu ve tebligat tamamlanmadı. Not içinden isim tahmini yapılmaz.
- Belirsiz ceza gönderiminde pencere aynı operation ID/payload ile retry yapar ve alanları kilitler. Taslak RAM'dedir, kalıcı/offline garanti yoktur.
- Yedi yeni Dart/widget test senaryosu hazır: üç konsol modül/masaüstü/ret notu testi ve dört veri model/sorgu/RPC testi. Flutter SDK PATH'te bulunamadı; konsol/veri `flutter test` ve `flutter analyze` çağrıları çalışmadı. Eski 40+ konsol testinin geçtiği veya kaynakların typecheck/build yaptığı iddia edilmez.
- Gerçek PostgREST, iki hesap/iki oturum, web widget/görsel UAT yapılmadı. SQL fixture Supabase auth/transport altyapısı için test adaptörleri kullanır.

## Yerel kontroller

- `node --test tools/federation_console_sql_test.mjs`: 68/68 geçti; önceki 63 senaryo + beş yeni 0113 güvenlik/işlem/tesis senaryosu.
- `node tools/platform_mission_control_sql_test.mjs`: 5/5 geçti.
- `python tools/check_migrations.py`: 113 dosyada parse hatası yok; parse çalışma zamanı doğrulaması değildir.
- `python tools/check_faq.py`: 40/40 bayrak yardımı; ek federasyon yardım kaydı idempotent.
- `python tools/check_push_routes.py`: 41 eşleme korunur.
- `PYTHONPATH=build/dart-syntax-check python tools/check_mobile_ui_tokens.py --syntax`: 557 Dart dosyası syntax, 16/16 mobil UI sözleşmesi; typecheck değildir.
- `git diff --check` / staged diff kontrolü: boşluk hatası yok.

Yalnız görev dosyaları stage edilir; önceki Faz 1–3 stage ve kullanıcı taslak planları korunur. Faz 4'ün açık antrenör/tahsis-yazma kapsamı ve Flutter doğrulaması nedeniyle tam üretim kabulü verilmez.
