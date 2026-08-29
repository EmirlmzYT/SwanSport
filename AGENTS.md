# SwanSport — ajanlar için proje kılavuzu

Spor kulüpleri için yönetim platformu ve spor ağı. **Flutter/Dart + Supabase.**
TypeScript değil — 151 Dart dosyası, 32 SQL migration, 14 JS dosyası (o da
Cloudflare fonksiyonları).

Bu dosya projeyi ilk kez gören bir ajan içindir. Kod tabanını taramadan önce
oku; buradaki bilgi tarayarak bulunacak şeyleri anlatmıyor, **tarayarak
bulunamayacak** şeyleri anlatıyor.

---

## Yapı

```
apps/swansport_app        mobil + web uygulaması (Android, Web)
apps/swansport_console    masaüstü yönetim konsolu (yalnızca Web, ≥900px)
packages/swansport_data   Supabase veri katmanı — İKİ UYGULAMANIN ORTAK KAYNAĞI
packages/swansport_core   ortam ve yapılandırma tipleri
packages/swansport_design_system  renk, tipografi, mobil bileşenler
supabase/migrations       şema — numaralı, idempotent, tek yetkili kaynak
apps/swansport_app/functions  Cloudflare Pages Functions (rss, push, konsol)
```

Melos workspace; kök `pubspec.yaml` içinde `workspace:` listesi var.

### Değişmezler

1. **Widget'tan doğrudan Supabase çağrılmaz.** Sorgular ve Riverpod
   sağlayıcıları `packages/swansport_data/lib/src/` altında düz durur.
2. **`swansport_data` arayüze bağlanmaz.** `IconData`, `Color`, widget, tema
   oraya girmez. Bir sabit hem veri hem görünüm taşıyorsa görünüm kısmı
   tüketen uygulamanın `presentation/` klasörüne gider.
3. **Yetki hesabı tek yerde:** `SwanAccess` (`swansport_data/lib/src/access.dart`).
   Mobil onu rota kümesine, konsol modül listesine çevirir. İkisi ayrı ayrı
   hesaplamaz — eskiden öyleydi ve sessizce ayrışıyordu.
4. **Arayüzde gizlemek güvenlik değildir.** Her kısıt veritabanında da olmalı
   (RLS ya da `security definer` fonksiyon içinde yetki kontrolü).

---

## Roller

| Rol | Nasıl belirlenir |
|---|---|
| Platform yöneticisi | `profiles.is_platform_admin` |
| Kulüp yöneticisi / antrenör | `club_memberships.role` |
| Antrenör kademesi (1–5) | **Onaylanmış belge** (`profile_credentials`), beyan değil |
| Sporcu (lisanslı/ferdi) | Onaylanmış belge; lisanslı = kulübü var |
| Veli | `guardians` tablosu |
| **Muhasebeci** | `club_accountants` — kulübün üyesi değil, dışarıdan hizmet veren |

**Kritik tuzak:** kimlik belgesi onaylandığında hiçbir yer `profiles.role`'ü
güncellemiyor. Bu yüzden yetki hesabı hem rolü hem belgeleri okumak zorunda.
Yalnızca role bakan kod, belge onaylandığında hiçbir şeyin değişmemesine yol
açar — bu gerçek bir hata olarak yaşandı.

---

## Muhasebeci gizliliği — dokunmadan önce oku

Muhasebeci kulübün defterini görür ama **sporcuları görmez.** Aidat satırları
para hareketi olduğu için gizlenemez; gizlenen kimin ödediğidir.

Uygulama biçimi:

- Muhasebeciye `athletes` tablosuna RLS erişimi **verilmedi**
- Mali okumalar `acc_*` RPC'lerinden geçer ve bu fonksiyonlar sporcu adını
  **hiç seçmez**
- Yerine `athlete_ref(uuid)` ile kimlikten türetilmiş sabit kod döner: `#A3F91C`

Bu ekranda gizleme değil, veri katmanında gizleme. `acc_ledger` ya da
kardeşlerine sporcu adı ekleyen bir değişiklik bu güvenceyi kırar.

---

## Bilinen tuzaklar

Hepsi bu projede gerçekten yaşandı; hiçbiri kodu okuyarak öngörülemez.

**PostgreSQL**
- `position` ve `current` ayrılmış sözcük — `RETURNS TABLE` içinde kullanılamaz
- `RETURNS TABLE` içinde `ORDER BY` **çıktı sütun adına göre yapılamaz**;
  konumsal (`order by 2`) ya da ifade kullan — ve konum sütun sayısını aşmasın
- `create or replace function` yalnızca **aynı imzayı** değiştirir. Parametre
  eklersen eski sürüm kalır, PostgREST `HTTP 300` döner ve özellik kırılır.
  Yeni imza yazarken eskisini `drop function` ile düşür.
- Fonksiyon izni kaldırırken **`public` rolünü unutma**: `anon` ve
  `authenticated`'dan almak yetmez, izin `PUBLIC`'ten miras alınır
- Supabase'de `postgres` gerçek superuser değil — `alter database ... set`
  reddedilir. Sır saklamak için **Supabase Vault** kullan.

**Supabase SQL Editor**
- Orada **oturum yoktur**: `auth.uid()` NULL döner. `auth.uid()` kullanan
  fonksiyonlar editörden test edilemez, boş döner. Bu bir hata değildir.
  Yetki gerektiren şeyleri ürünün kendisinden test et.

**Konum**
- `geolocator` yalnızca kort tarafında kullanılıyor. Android'de
  `ACCESS_FINE_LOCATION` izni manifest'te; arka planda konum **izlenmiyor**,
  yalnızca kullanıcı bir eylem yaparken isteniyor.
- İstemcinin gönderdiği koordinata güvenilmez: yetki kararı sunucudaki
  `meters_between` ile veriliyor. `court_service.dart` içindeki Dart kopyası
  yalnızca listeyi yakınlığa göre **sıralamak** için.

**Flutter / dağıtım**
- `flutter` alt çizgiyle başlayan dosyaları (`web/_redirects`) `build/web`'e
  **kopyalamaz** — dağıtımda elle kopyalanır
- Cloudflare, hedefi `/index.html` olan 200 rewrite kurallarını **sessizce yok
  sayar** (`Parsed 0 valid redirect rules`). Konsol yönlendirmesi bu yüzden
  `functions/konsol/[[path]].js` içinde.
- Git Bash `--base-href=/konsol/` değerini Windows yoluna çevirir;
  `MSYS_NO_PATHCONV=1` gerekir
- Flutter web canvas'a çizer: DOM ve erişilebilirlik ağacı **boş** döner.
  Playwright/DOM tabanlı metin doğrulaması çalışmaz; ekran görüntüsü çalışır.

---

## Çalıştırma ve doğrulama

```bash
flutter analyze packages/swansport_data apps/swansport_console apps/swansport_app
```

```bash
cd packages/swansport_data && flutter test     # 62 test, hepsi geçer
```
```bash
cd apps/swansport_console && flutter test      # 40 test, hepsi geçer
```
```bash
cd apps/swansport_app && flutter test          # 105 test, hepsi geçer
```

Konsol 50'den 40'a **düşmedi, taşındı**: `money_test` (10 test) `fmtMoney`
ile birlikte `swansport_data`'ya geçti. Toplam sayı korunuyor.

Mobil testlerde ortak Supabase ve bellek içi `shared_preferences` kurulumu
`cfc985c` ile eklendi; eski `_instance._isInitialized` kök nedeni kalktı.
Sabit genişlikte uzun etiketlerin düğme taşması
`d509945`, eksik ekip performansı rotası `d6e85f6`, duyuru araması
`e96855f`, gerçek Supabase sporcu ayrıntı testleri de `5978e0d` ile
tamamlandı.

Derleme çıkış kodunu ayrı satırda oku, `| tail` ile boru hattına sokma.

### Dağıtım

Mobil ve konsol **aynı Cloudflare Pages projesinde**, aynı origin altında:
`swansport.pages.dev/` ve `swansport.pages.dev/konsol/`. Aynı origin olması
tercih: ayrı origin ayrı `localStorage`, o da iki kez giriş demekti.

```bash
cd apps/swansport_app && flutter build web --release -t lib/main_production.dart --dart-define-from-file=env/prod.json
```
```bash
cd apps/swansport_console && MSYS_NO_PATHCONV=1 flutter build web --release -t lib/main_production.dart --dart-define-from-file=env/prod.json --base-href=/konsol/
```
```bash
cp -r apps/swansport_console/build/web apps/swansport_app/build/web/konsol && cp apps/swansport_app/web/_redirects apps/swansport_app/build/web/_redirects
```
```bash
cd apps/swansport_app && npx wrangler pages deploy build/web --project-name=swansport --branch=main
```

Ekranda görünmesi gereken bir değişiklik yaptıysan **dağıtımı da yap** —
yoksa kullanıcı eski derlemeye bakar ve "hani" der. Bu yaşandı.

---

## Durum

### Çalışan

Sosyal akış, mesajlaşma, şehir bazlı antrenör toplulukları, federasyon
duyuru kanalları, sporcu/kadro, takvim ve tekrarlayan antrenman, etkinlik
katılım onayı (RSVP), yoklama ve
denetim izi, performans testleri, sağlık, belgeler, tesisler, aidat ve bağış,
kimlik doğrulama, platform yönetim paneli, keşif/ilanlar/organizasyonlar.

Masaüstü konsolu: sporcular, takvim, yoklama, tesisler, gelir–gider, kasa,
mali rapor, onaylar, kullanıcılar, moderasyon, metrikler.

Web push çalışıyor (RFC 8291 + VAPID, `functions/api/push.js`).

İlan panosu (`listings`) hem insan hem **malzeme** ilanı taşıyor:
`equipment_sale` / `equipment_wanted`. Ayrı bir "ürünler" tablosu yok — bu
bir ilan panosu, mağaza değil; ödeme, kargo ve iade yok, taraflar mevcut
`/sohbet` ekranından anlaşır. Kişisel malzeme ilanı **onaylanmış belge**
istiyor (`has_approved_credential`); platformun dolandırıcılığa karşı tek
gerçek avantajı bu.

Para biçimlendirme (`fmtMoney`, `fmtDate`, `kMonthNames`) artık
`swansport_data/lib/src/money.dart` içinde — konsol ve mobil aynı kaynağı
kullanıyor.

### Halka açık kortlar — ayrı bir dünya

`courts`, `court_slots`, `court_slot_players`, `court_players` (0035). Konya'da
halka açık tenis kortlarında sıra sistemi. Sahadaki kuralı değiştirmiyor,
dijitalleştiriyor: *orada olan oynar* — sistem yalnızca beklemeyi kortun
kenarından eve taşıyor. Bu yüzden hiçbir resmî yaptırıma ihtiyacı yok.

Kulübün `facilities` tablosuyla karıştırma: o kulübe ait, koordinatsız,
yalnızca üyeye görünür. Kort halka açık, koordinatı şart.

**Ayrılabilirlik kuralı — bunu bozmayın.** Kort dünyası bir gün kendi
uygulamasına ayrılacak (hesap aynı kalacak). İki kural:

1. Kort verisi kulüp tablolarına karışmaz — gelmeme sayacı `profiles`'a değil
   `court_players`'a yazılıyor.
2. `apps/swansport_app/lib/features/courts/` altında kulüp kavramı geçmez.
   Kontrolü basit:
   `grep -rnE "activeClub|isClubStaff|athlete|invoice" apps/swansport_app/lib/features/courts/`
   → **boş dönmeli.** Bozulursa ancak ayrılma günü fark edilir, o zaman geç olur.

Sıra kuralları (`claim_slot` içinde, tek yerde): kişi başına tek aktif kutu ·
en fazla 3 saat ileri · sırası gelince konum kanıtı (10 dk, yoksa kutu düşer) ·
üç kez üst üste gelmeyene bir hafta yasak · iptal cezasız · uzatma yalnızca
sonraki kutu boşsa.

**`unique (court_id, starts_at)` bilerek konuldu:** iki kişi aynı saniyede aynı
saati alamaz, çakışmayı veritabanı çözer. Bunu koda taşımayın.

**Doğrulama kademesi** `profiles.verification_tier`: `none | location | phone
| id`. Bugün yalnızca `location` erişilebilir (kortta bir kez bulunmak).
SMS ve TC altyapı olarak duruyor, **kullanılmıyor** — SMS mesaj başına para
yakıyor, TC ise kayıt sürtünmesini artırıp hedef kitleyi kaçırıyor.
`SwanAccess.rankOf` ile SQL'deki `verification_rank` aynı sırayı tutmalı.

**Konum sahtecilik sınırı:** konumu istemci gönderiyor, sunucu mesafeyi
hesaplıyor. `Position.isMocked` sıradan istismarı kesiyor ama kararlı biri
aşar. Bedava tenis kortu için kabul edilen bir risk; gerçek çözüm korta QR
asmak ve o da belediye görüşmesine bağlı.

**Çift dokunuş tuzağı (0036'da düzeltildi):** `claim_slot`/`extend_slot`'ta
ağ gecikmesiyle iki istek üst üste gidince ikisi de "zaten sıram var mı"
kontrolünü kutu henüz yazılmadan geçip unique kısıtına çarpıyordu — çakışan
her zaman kendi isteğiydi ama "başkası aldı" diyordu. Düzeltme: çakışma
anında satırın sahibine bakılıyor, sahibi çağıran kişiyse hata değil, var
olan kutu dönüyor. Gerçek cihazda denendi, doğrulandı (2026-08-30).

#### Kort partneri arama (0037)

`sport_interests`, `partner_requests`, `partner_request_pings`. Kort
sisteminin tamamlayıcısı: `open_slots` saat almış olmayı şart koşuyor, bu
saat almadan "şimdi/yakında oynamak istiyorum" diyebilmeyi çözüyor. Biri
`seek_partner` çağırınca sistem yakındaki ilgili kişilere toplu bildirim
atıyor (`send_attendance_reminders`'daki toplu-insert deseniyle); kabul
onaylı — `respond_partner_ping`, atomik `update ... where status='open'` ile
iki kişinin aynı isteği neredeyse aynı anda kabul etmesini `claim_slot`'un
unique kısıtıyla aynı ilkeyle çözüyor (satır kilidi, ikinci çağrının WHERE'i
artık tutmuyor).

**"Yakınında" ŞEHİR bazlı, GPS değil — bilinçli karar.** Kime bildirim
gideceğine karar vermek için tüm adayların canlı konumunu bilmek gerekirdi;
bu arka planda sürekli izleme demek, courts'ta bilerek kaçınılan şey.
`profiles.city_code` ile kaba eşleşiyor. İsteyenin kendi konumu yine yalnızca
o an alınıyor (`place.dart`), ama kime bildirim gideceğine karışmıyor.

**Güven mekanizması courts ile paylaşılıyor, tekrar yazılmadı:**
`verification_tier` ve `court_players.banned_until` aynen kullanılıyor.
Somut sonucu: **yeni kullanıcı önce bir kortu fiziksel ziyaret etmeden
partner arayamaz** — doğrulama oradan geliyor. Bu bir tuzak değil, bilinçli
sıra: kort → doğrulan → partner ara.

**Konsol kort formu artık branş istiyor** (`sport_code` dropdown,
`courts_screen.dart`). `court_sport_codes()` RPC'si buna dayanıyor — branşsız
kort eşleştirmeye hiç girmiyor. **Millet Bahçesi ve Şefikcan Parkı'nın
branşı henüz elle güncellenmedi**, güncellenene kadar partner arama aday
havuzu bu iki kort için boş kalır.

#### Halı saha doluluk panosu (0038)

`turf_fields`, `turf_field_managers`, `turf_occupancy`. Kort sisteminden
**kasıtlı olarak daha hafif**: halı sahanın sahibi var, ücretli, rezervasyon
telefonla/yerinde yapılıyor — burası yalnızca **ilan panosu**, rezervasyon
kilidi ve ödeme yok. İşletme yetkilisi hangi saatlerin dolu olduğunu
işaretliyor, oyuncu görüp arıyor, döndüğünde işaretliyor.

`courts`'tan farkı: **rekabet yok**, tek yetkili kişi bir gerçeği yazıyor.
Bu yüzden `claim_slot` gibi bir RPC yok — `turf_occupancy_manage` RLS
kuralı (`is_turf_manager(field_id)`) yetkiyi doğrudan kesiyor, mobil
`.from('turf_occupancy').insert()/.delete()` çağırıyor. `turf_occupancy`'de
ayrı bir `status` sütunu da yok: **satır varsa dolu, yoksa boş.**

**Davet sıfırdan yazılmadı** — kulüp muhasebecisi daveti zaten `invite_codes`
+ `redeem_invite_code`'da vardı (`purpose` alanıyla ayrışıyor), üçüncü dal
(`turf_manager`) eklendi. Kod `/veli-bagla` ekranından girilir — o ekran
zaten amaç-bağımsız tasarlanmıştı, dokunulmadı.

**Tek ekran, iki rol.** Ayrı bir "Saha Yönetimi" ekranı yok: `/halisahalar`
→ `/halisaha` courts'un kort listesi/ayrıntısı deseninin aynısı, yönetici
olan kişi (`SwanAccess.isTurfManagerOf`) aynı ekranda fazladan bir dokunma
kontrolü görüyor.

Sahalar courts gibi **elle ekleniyor** (konsol), yöneticisi de yalnızca
platform yöneticisinin ürettiği davet koduyla atanıyor — işletme kendi
kaydolamıyor.

Migration'lar **0037'ye kadar canlıda kurulu** (2026-08-30 doğrulandı):
mali defter sayfalaması, yoklama denetim izi, etkinlik katılım onayı,
malzeme ilanları, halka açık kortlar (çift dokunuş düzeltmesiyle) ve kort
partneri arama şemada var. `0038_turf_venues.sql` **henüz sürülmedi.** Yeni
migration yazarken numarayı 0039'dan sürdür.

Web dağıtımı 2026-08-30'da yapıldı; canlı derleme kort partneri aramayı
içeriyor, halı saha panosunu (0038 sürülüp derlenene kadar) içermiyor.

### Yarım / doğrulanmamış

- **Android push (FCM)** — izin, bildirim kanalı, ön plan uyarısı ve bildirim
  dokunuşunda rota açma akışı `f2e16a1` ile tamamlandı; debug APK derlendi.
  Cloudflare tarafında `FCM_SERVICE_ACCOUNT` sırrı **tanımlı** (2026-08-30
  `wrangler pages secret list` ile doğrulandı). **Gerçek cihazda bildirimin
  ulaştığı henüz doğrulanmadı** — bu makinede `adb` yok.
- **Muhasebeci görünümü** — kodda ve RLS'te doğru, ama sadece muhasebeci olan
  ikinci bir hesapla hiç denenmedi
- **Release keystore yok** — imza yapılandırması hazır ve `app-release.aab`
  derleniyor, fakat Play Store'a yüklemek için kullanıcı kendi anahtarını
  `android/key.properties` ile sağlamalı

- **Halka açık kortlar** — şema canlıda, web dağıtıldı, sıra alma gerçek
  cihazda denendi ve doğrulandı (0036 sonrası). Belediye görüşmesi bundan
  sonra.
- **Kort partneri arama** — şema canlıda (0037), web dağıtıldı, kortların
  branşı set edildi (kullanıcı 2026-08-30'da onayladı). Uçtan uca hiç
  denenmedi — en az iki hesap, aynı şehir, aynı branş ilgi alanı gerekiyor.
- **Halı saha doluluk panosu** — kod ve testler hazır, `0038_turf_venues.sql`
  **canlıda çalıştırılmadı**, mobil derleme dağıtılmadı. Migration sürülse
  bile konsoldan hiç saha eklenmedi; saha eklenip yönetici daveti
  redeem edilmeden ekranın düzenleme tarafı hiç test edilemez.

### Dış bağımlılık bekleyen

Online kart ödemesi (iyzico/PayTR üye iş yeri), KVKK aydınlatma metni
(hukukçu), Supabase'de "Confirm email" ayarı.

### Commit durumu

Çalışma alanı temiz; her iş kendi commit'inde. Ne yapıldığını `git log --oneline`
söyler, burada tekrarlanmaz — commit listesini elle sürdürmek onu eskitiyordu.

Beklenmedik bir değişiklik görürsen sahibini ve kapsamını doğrulamadan üzerine
yazma.

---

## Sırlar

Depoda sır **yoktur ve olmamalıdır**. `env/` gitignore'da.

- `env/prod.json` — Supabase URL + **anon** anahtar (anon anahtar herkese
  açıktır, web paketinde zaten görünür; koruma RLS'te)
- `google-services.json` — gitignore'da, ama zaten her APK'nın içinde dağıtılır
- Firebase servis hesabı anahtarı, `PUSH_SECRET`, VAPID anahtarları →
  **Cloudflare Pages secret'ları**; `PUSH_SECRET` ayrıca Supabase Vault'ta
- `service_role` anahtarı hiçbir yerde kullanılmaz

Sır gerektiren bir adıma gelirsen dur ve kullanıcıya ne gerektiğini söyle.
Anahtar üretip sohbete yazma — kullanıcı kendi terminalinde üretsin, doğrudan
hedefine koysun.

---

## Çalışma kuralları

- **Önce sembolü bul, sonra dosya oku.** Tüm projeyi tarama.
- **Önce mevcut implementasyonu ara.** Bu depoda çoğu şeyin karşılığı zaten
  var; ikinci bir kopya yazmak geçmişte üç kez sessiz çakışma üretti
  (`InjuryRow`, `injuriesProvider`, `attendanceSummaryProvider`).
- **Büyük dosyanın tamamını okuma** — aralık al.
- **İstenmeyen refactor ve özellik ekleme.** Kapsam neyse o.
- Veritabanı/SQL, güvenlik-yetki ve "hata vermiyor ama garip davranıyor"
  işlerinde dikkatli ol; bu üçünde sessiz hata üretme olasılığı yüksek.

---

## Bu dosyayı güncel tut

Bu dosya projeyi ilk kez gören ajanın tek başlangıç noktası. İş bitirdikten
sonra şunlardan biri olduysa güncelle:

- Yeni modül, tablo, migration ya da paket → **Yapı** ve **Durum**
- Yeni tuzak bulundun (sessiz hata, platform kuralı) → **Bilinen tuzaklar**
- Bir şey çalışır ya da bozuk hale geldi → **Durum**
- Test sayısı değişti → **Çalıştırma ve doğrulama**
- Commit atıldı / yeni iş commit'lenmedi → **Commit durumu**
- Yeni sır tanımlandı → **Sırlar**

Küçük düzeltmeler için gerekmez.

Eskimiş bir kılavuz, hiç kılavuz olmamasından kötüdür: okuyan ona güvenip
yanlış yola sapar.
