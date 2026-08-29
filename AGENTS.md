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

Migration'lar **0035'e kadar canlıda kurulu** (2026-08-29 doğrulandı): mali
defter sayfalaması, yoklama denetim izi, etkinlik katılım onayı, malzeme
ilanları ve halka açık kortlar şemada var. Yeni migration yazarken numarayı
0036'dan sürdür.

Web dağıtımı 2026-08-29'da yapıldı; canlı derleme malzeme ilanlarını
içeriyor.

### Yarım / doğrulanmamış

- **Android push (FCM)** — izin, bildirim kanalı, ön plan uyarısı ve bildirim
  dokunuşunda rota açma akışı `f2e16a1` ile tamamlandı; debug APK derlendi.
  **Gerçek cihazda henüz test edilmedi**: bu makinede `adb` yok ve Cloudflare
  tarafında `FCM_SERVICE_ACCOUNT` sırrı tanımlanmalı.
- **Muhasebeci görünümü** — kodda ve RLS'te doğru, ama sadece muhasebeci olan
  ikinci bir hesapla hiç denenmedi
- **Release keystore yok** — imza yapılandırması hazır ve `app-release.aab`
  derleniyor, fakat Play Store'a yüklemek için kullanıcı kendi anahtarını
  `android/key.properties` ile sağlamalı

- **Halka açık kortlar** — şema canlıda, web dağıtıldı. Ama **konsoldan
  henüz kort eklenmedi**; kort eklenmeden ekran boş görünür ve koordinat
  olmadan kimse kortta olduğunu doğrulayamaz. Gerçek cihazda konum akışı da
  denenmedi. Belediye görüşmesi bundan sonra.

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
