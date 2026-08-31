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

**Tasarım jetonları — `app/design/`**
- `swan_type` (7 adım), `swan_palette`, `swan_shape`. **Ham sayı yazma:**
  `jakarta(11.5, ...)` yerine `SwanType.caption(...)`. Ölçtüğümde 28 farklı
  yazı boyutu vardı, 1001 çağrıda — görsel hiyerarşi bu yüzden kurulamıyordu.
- **Konsolun `swansport_design_system` paketinden ayrı, bilerek.** O paketi
  masaüstü konsolu da kullanıyor; mobil-sosyal dili oraya taşımak konsolu
  bozar. Kanıt olarak konsol testleri 40'ta sabit tutuluyor.
- Palet çakışması çözüldü: ekranların gerçekte kullandığı değerler kazandı
  (`0xFF131D2E`, 196 kullanım), tasarım sistemindeki `0xFF171A1F` değil.
  **Anlam renklerinde de aynı hata bir kez tekrarlandı** — jetonları ilk
  yazarken `danger`'a kendi değerimi koymuştum, ekranlar 140 yerde başkasını
  kullanıyordu. Yeni bir jeton eklerken **önce say**: `grep -rho
  "Color(0xFF……)" | sort | uniq -c`. Uydurma, ölç.
- **Ham `jakarta()`/`sora()` çağrısı `features/` altında sıfır.** 1001 çağrı
  yedi adıma indi. Yeni ekranda ham sayı yazma.
- Sabit hex 801'den 91'e indi; kalanlar tekil ve anlamlı (kategori renkleri,
  marka gradyanları). Jetonlar `isDark ? SwanPalette.dark : .light` biçiminde
  okunuyor — `context.swan` yalnızca `context` kapsamdayken çalışır, yardımcı
  metotların çoğunda değil.
- Jeton okuyan ifade **`const` olamaz** (derleme zamanı sabit değil).
- Koyu temada **saf siyah yok** — navy/charcoal (brief kuralı).
- `accent` (teal) yalnızca birincil aksiyon ve aktif durum içindir;
  dekoratif teal için jeton bilerek yok.

**Gezinme — 5 öğe, modül menüsü YOK**
- `SwanBottomNav`: Ana Sayfa · Keşfet · + · Mesajlar · Profil. Parametre
  almaz; aktif sekmeyi açık rotadan çıkarır. Eskisi
  `selectedIndex/onSelect/onAction` istiyordu ve 31 ekranın 25'i boş geçiyordu.
- **Rol-uyarlamalı yuvalar kaldırıldı** — aynı konum kişiden kişiye farklı
  şey açıyordu, kas hafızası kurulamıyordu. Rol farkı artık sekmede değil
  **içerikte**: antrenörün yoklaması Ana Sayfa'daki "Bugün" ve
  Profil > Yönetim'de.
- **`module_launcher.dart` silindi ama hiçbir rota silinmedi.** Keşif
  modülleri `explore_screen`'e, kişisel/yönetim `management_section`'a
  taşındı. `navigation_test.dart` her rotanın bir giriş noktası olduğunu
  doğruluyor — yeni rota eklerken oraya da satır ekle, yoksa rota tanımlı
  kalır ama hiçbir yerden açılamaz.

**Birleşen sayfalar — eski rotalar korunur**
- Üç sayfa sekmeli tek sayfaya birleşti: **Sahalar** (`/kortlar` +
  `/halisahalar`), **Mesajlar** (`/mesajlar` + `/topluluklar`), **Partner
  Bul** (`/partner-ara` + `/oyuncu-aranan`). **Eski rotaların hepsi hâlâ
  tanımlı** ve doğru sekmeye açılıyor (`initialTab`) — `push_route`'un
  ürettiği bildirim derin bağlantıları bunlara dayanıyor, kaldırma.
  `merged_routes_test.dart` bu sözleşmeyi koruyor.
- Gizlilik menüden çıkarıldı ama rotası duruyor: Ayarlar'ın içinden
  açılıyor (`club_settings_screen`), üst düzey menüde ayrı giriş gereksizdi.
- Sekme çubuğu için `app/widgets/swan_tabs.dart` kullan, yerel kopya yazma:
  `SwanSegmentedTabs` (2–3 kısa etiket) ve `SwanPillTabs` (çok etiket +
  rozet). **İki stil bilerek ayrı** — tek stile zorlamak `finance_screen`'in
  dört sekmesini ve rozetini bozardı.
- Ekranlar arası kısayol için `app/widgets/quick_actions.dart`. Uygulama bir
  menü kataloğu gibi çalışıyordu; bu bileşen "sayfa sayfayı açar" akışını
  taşıyor.

**Bilerek birleştirilmeyen ikisi**
- **Yoklama Al + Devam Geçmişi:** biri yazma akışı (`_marks` state'i, kendi
  kaydet barı), öbürü salt okuma. Sekme değiştirmek **işaretlenmiş ama
  kaydedilmemiş yoklamayı yakar.**
- **Antrenör Paneli + Komuta Merkezi:** ikisi aynı veriyi gösteriyor ama
  `coach_dashboard` aynı zamanda rol yönlendiricisi (sporcu/veli/üye için
  başka ekran döndürüyor). Doğrusu sekme değil, birini silmek — ayrı karar.

**Ekran kabuğu (üst bar / alt bar)**
- **Kural:** üst sağ = gelen kutusu (zil + mesaj, ikisi de rozetli ve
  tıklanır, `app/widgets/inbox_actions.dart`), alt bar = bölümler arası
  gezinme, **header'daki avatar yalnızca kimlik göstergesi** — gezinme
  hedefi değil, Profil zaten alt barda. Aynı hedefe iki buton koyma.
- Zil ve mesaj rozetleri **birbirini dışlar**: 0040'tan beri her doğrudan
  mesaj bir `notifications` satırı da üretiyor, o yüzden `unreadCount()`
  `kind <> 'message'` süzüyor ve mesajlar `unreadMessageCount()` ile ayrı
  sayılıyor. Bu ayrımı bozarsan aynı mesaj iki rozette birden görünür.
- Zil beş ana ekranda **ölüydü** (düz `Container`, `onTap` yok) ve bu ancak
  elle denenince fark edilirdi. `inbox_actions_test.dart` artık dokunmanın
  çalıştığını test ediyor; yerel bir `_bell` kopyası yazma.

**Realtime**
- Bir tablonun canlı akması için **`supabase_realtime` publication'ına
  eklenmiş olması** şart. Eklenmeden `.stream()` yazmak sessizce çalışmıyor:
  abonelik kuruluyor, hata da vermiyor, ilk anlık görüntü bile geliyor — ama
  hiçbir güncelleme düşmüyor. DM'ler tam bu yüzden canlı değildi; 0016
  yalnızca `community_messages`'ı eklemiş, `direct_messages` 0042'ye kadar
  dışarıda kalmıştı.
- `.stream()` **tek bir filtre** kabul ediyor. Bir DM sohbeti
  `(ben→o) VEYA (o→ben)` demek ve bu bir `or`; stream API'sinde yeri yok.
  Çözüm: filtreyi zamana koy (`gte('created_at', ...)`), karşı tarafı
  istemcide süz. RLS zaten başkasının satırını vermiyor, güvenlik açığı
  değil.
- `replica identity full` olmadan UPDATE olayları eski satırı taşımıyor.
  DM'de bu okundu bilgisi demek — onsuz çift tik hiç görünmez.
- **Akış hatası ekranı düşürmemeli.** Publication'da olmayan bir tabloya
  `.stream()` açmak hata fırlatıyor; bu hata `StreamProvider`'dan yukarı
  taşınırsa ekran, elinde duran veriyi göstermek yerine "Veri yüklenemedi"
  diyor. Bir kez canlıda böyle kırıldı. `mergeChat`
  (`notification_service.dart`) deseni: geçmişi her hâlükârda yayınla, akış
  hatasını yut, yoklamaya düş. `dm_test.dart` bunu sabitliyor.

**Push kaydı**
- Cihaz kaydı `register_push_subscription` RPC'siyle yapılıyor (0043),
  doğrudan `upsert` ile **değil**. Sebep: `push_subscriptions.endpoint`
  globalde tekil ve RLS `using (profile_id = auth.uid())`. Postgres
  `ON CONFLICT DO UPDATE`'te `USING`'i **mevcut satıra** uyguluyor, yani cihaz
  daha önce başka bir hesapla kaydedildiyse yeni hesap o satıra dokunamıyor ve
  insert `42501` ile düşüyor. Aynı telefonda iki hesapla giriş yapmak yeter.
  Belirti: aç/kapa çalışmıyor **ve** bildirim hiç gelmiyor — tek hata, iki
  belirti.
- Cihaz adresi yeni hesaba **devrediliyor**. FCM token'ı kullanıcıya değil
  uygulama kurulumuna ait; telefonda hesap değişince o cihaza gidecek
  bildirimler de yeni hesabın olmalı.
- Kayıt kontrolü de RPC (`push_subscription_state`): düz `select` başkasına
  ait satırı RLS yüzünden **boş** döndürüyor ve tanılama bunu "kayıt yok"
  diye gösteriyordu — yanlış teşhis.

**Sohbet ekranı**
- Klavye dolgusuna `viewInsets.bottom` **ekleme**. Scaffold
  `resizeToAvoidBottomInset` ile gövdeyi zaten küçültüyor; üstüne eklemek aynı
  boşluğu iki kez sayıyor ve yazı alanı klavyenin bir boy yukarısına fırlıyor.
  İki sohbet ekranında da bu hata vardı.
- Mesaj listesi `reverse: true` (WhatsApp deseni): en yeni mesaj sıfır
  konumunda. Klavye açılınca liste kaydığı yerde kalmıyor. Öğelere sondan
  erişiliyor, `_scrollToEnd` **sıfıra** gidiyor — `maxScrollExtent` ters
  listede en eski mesaj demek.
- `OpenChat` (`push_service.dart`) açık sohbeti tutuyor; push dinleyicisi
  o kişiden gelen ön plan uyarısını bastırıyor. Eşleşme **ada** göre, çünkü
  push yükü gönderen kimliğini taşımıyor — yalnızca `"<Ad> size yazdı"`.
  Ad tutmazsa bildirim gösteriliyor: yanlışlıkla göstermek, yanlışlıkla
  gizlemekten iyi.

**Gezinme ve giriş noktaları**
- Modül menüsü (`module_launcher.dart`, `kAllModules`, `kModuleGroup`) tasarım
  turunda **kaldırıldı**; rotalar duruyor, giriş noktaları Keşfet ve
  Profil > Yönetim'e dağıldı. Yeni bir ekran eklerken menüye satır aramaya
  çalışma — menü yok. Bunun yerine `navigation_test.dart` her rotanın en az bir
  giriş noktası olduğunu zorunlu kılıyor; ekranı ekleyip bir yerden
  bağlamazsan test düşer.

**Türkçe arama**
- `trFold` / `trContains` kullan (`app/util/tr_text.dart`). Sorun `İ` değil —
  onu ölçtük, Dart `'İ'.toLowerCase()` için düz `i` veriyor. Asıl sorun
  şapkalı harflerin ve noktasız `ı`'nın olduğu gibi kalması:
  `'Işıklar'.toLowerCase().contains('isiklar')` **false**. Kullanıcı "isiklar"
  yazınca "Işıklar Kort" bulunmuyor.
- **Beş arama ekranı hâlâ düz `toLowerCase()` kullanıyor** ve bu hatayı
  taşıyor: `announcements_screen`, `communication_center`,
  `configuration_controller`, `document_vault`, `search_screen`.
  `tr_text_test.dart` yardımcıyı sabitliyor ama çağrı yerlerini değil.

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
cd packages/swansport_data && flutter test     # 102 test, hepsi geçer
```
```bash
cd apps/swansport_console && flutter test      # 40 test, hepsi geçer
```
```bash
cd apps/swansport_app && flutter test          # 150 test, hepsi geçer
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

**`flutter analyze` çıktısını süzerken deseni doğrula.** Bu sürümün biçimi
`error - ...`; eski sürümlerdeki `error • ...` **değil**. Yanlış desenle
süzmek her koşuda sıfır döndürür ve hiç hata yokmuş gibi görünür — bu
oturumda tam olarak bu oldu, bir tur boyunca "0 hata" diye rapor edilen şey
aslında hiçbir şey saymıyordu. Hatayı `flutter test` derleyicisi yakaladı
(eksik `import`, `SwanRadius` tanımsız).

```bash
flutter analyze packages/swansport_data apps/swansport_console apps/swansport_app > /tmp/an.txt 2>&1; grep -cE "^\s+error - " /tmp/an.txt
```

Taban: **0 hata, 0 uyarı**, ~2340 `info` (lint önerisi). `info` sayısı
gürültü; `error` ve `warning` sıfır kalmalı.

**Migration yazdıysan söz dizimini denetle.** Migration'lar Supabase SQL
Editor'e elle yapıştırılıyor; söz dizimi hatası ancak orada, yarım uygulanmış
bir migration olarak ortaya çıkıyor — en kötü yer.

```bash
pip install pglast && python tools/check_migrations.py
```

Gerçek PostgreSQL ayrıştırıcısını kullanıyor, çalıştırmıyor. **Sınırı var:**
söz dizimi dışında bir şey doğrulamıyor — olmayan tabloya referans, yanlış
tip, eksik izin hepsi buradan geçer. "Parse oldu" ile "çalışır" aynı şey
değil.

**`analyze` temiz diye derleme temiz sayma.** İkisi ayrı ön uç kullanıyor ve
test derleyicisi bazı çözümleme hatalarını `analyze`'dan önce/farklı
yakalıyor. Bir işi bitirmeden önce ikisini de çalıştır.

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

**`-t` ve `--dart-define-from-file` unutulursa build başarılı olur, uygulama
ölür.** Düz `flutter build web --release` çıkış kodu 0 verir, analyzer temiz,
testler geçer — ama tarayıcıda gri ekran açılır ve konsola
`LateInitializationError: Field '' has not been initialized.` düşer. Sebep:
Supabase anahtarları derlemeye girmez, `Supabase.initialize` başarısız olur,
`Supabase.instance.client` okunduğu anda patlar. Hiçbir yerel doğrulama bunu
yakalamaz; yalnızca canlıda görünür. Dağıtımdan sonra derlemede anahtarın
gerçekten olduğunu doğrula:

```bash
grep -c "gokkimnokigqxmbppvle" apps/swansport_app/build/web/main.dart.js
```

Konsol `build/web/konsol/` altında duruyor ve `flutter build web` onu
**silmiyor** — mobil yeniden derlendiğinde konsol yerinde kalıyor. Yine de
konsolda değişiklik yaptıysan kopyalama adımını atlama.

**Doğrularken taze sekme aç.** Tarayıcı aracının konsol arabelleği sayfa
yenilemede temizlenmiyor; bozuk bir yüklemeden kalan hata, düzeltilmiş
sayfada da görünmeye devam ediyor. Aynı sekmede yenileyip "hata duruyor"
diye okumak yanlış teşhise götürüyor — bu oturumda iki kez oldu.

`curl` bu makinede TLS hatası (exit 35) veriyor; `HTTP 000` "site kapalı"
demek değil, "curl bağlanamadı" demek. Canlı doğrulamayı tarayıcıyla yap.

Ekranda görünmesi gereken bir değişiklik yaptıysan **dağıtımı da yap** —
yoksa kullanıcı eski derlemeye bakar ve "hani" der. Bu yaşandı.

### APK güncelleme bildirimi

Play Store'da değiliz; APK sideload ile dağıtılıyor.
`apps/swansport_app/lib/app/update/update_checker.dart`
açılışta **public** GitHub deposunun (`EmirlmzYT/SwanSport`) en son
release'ini (`/releases/latest` API'si, kimlik doğrulama gerektirmiyor)
kendi sürümüyle kıyaslıyor, yeniyse banner gösteriyor. "Güncelle" denince APK **uygulama içinde**
indiriliyor (ilerleme çubuğuyla, `update_downloader.dart`) ve Android
kurulum ekranı açılıyor.

**Sınır:** Android yine "bilinmeyen kaynaklardan kuruluma izin ver" iznini ve
kendi kurulum onay ekranını gösterir — bu işletim sistemi seviyesinde,
atlatılamaz. Kaldırılan şey tarayıcıya atlayıp indirilenler klasöründe dosya
arama adımı. Kurulum başlatılamazsa diyalog tarayıcıya düşme seçeneği
sunuyor.

İndirme kodu elle yazıldı (`http` zaten bağımlılık): hazır "güncelleyici"
paketlerinin hepsi çok az kullanılan küçük paketlerdi, güncelleme yolu gibi
kritik bir yere bakımsız kod konmadı. Üçüncü parti yalnızca son adımda —
`apk_sideload` Android'in FileProvider + kurulum intent'ini hallediyor.
`REQUEST_INSTALL_PACKAGES` izni ve FileProvider o paketin manifest'inden
birleşiyor, bizim manifest'e elle eklenmedi. **Play Store'a gidilirse bu izin
politika gerekçesi ister** — o gün bu mekanizma zaten gereksizleşir, kaldırın. Yalnızca Android'de çalışır (`update_gate.dart`'ta
`kIsWeb`/`TargetPlatform.android` kontrolü) — web zaten her deploy'da
otomatik güncel.

**Yeni bir APK yayınlarken:**

1. `apps/swansport_app/pubspec.yaml`'daki `version:` satırını artır
   (`0.1.1+2` gibi — nokta kısmı sürüm adı, `+` sonrası build numarası;
   yalnızca build artsa bile kullanıcıya haber gider).
2. `cd apps/swansport_app && flutter build apk --release -t lib/main_production.dart --dart-define-from-file=env/prod.json`
3. `gh release create v<pubspec-sürümü> apps/swansport_app/build/app/outputs/flutter-apk/app-release.apk --repo EmirlmzYT/SwanSport --title "..." --notes "..."`

Tag adı **`v` + pubspec sürümü** olmalı (`v0.1.1+2`) — kod bunu ayrıştırıyor.
Zaten kurulu APK'lar bir sonraki açılışta otomatik haber alır, sen ayrıca
dosya göndermek zorunda kalmazsın.

**Web'e dağıtmak APK'yı güncellemez.** Bu ikisi ayrı zincir ve karıştırmak
kolay: 31 Ağustos – 1 Eylül'de web beş kez dağıtıldı, APK'daki kullanıcılar
30 Ağustos kodunda kaldı. Kimse hata görmedi çünkü ortada hata yoktu —
sunacak yeni sürüm yoktu. **Mobil tarafta iş bitirdiysen sürümü artırıp
release yayınlamayı ayrı bir adım olarak say.**

**İmza sürekliliği.** `android/key.properties` yok, yani release APK
**debug anahtarıyla** (`~/.android/debug.keystore`) imzalanıyor. Android
imzası farklı bir güncellemeyi kurmaz — kullanıcı "Uygulama yüklenmedi"
alır ve bunu ancak şikayetten öğrenirsin. O keystore silinir ya da yeniden
üretilirse **kurulu tüm APK'lar güncellenemez hâle gelir**; tek çıkış
kaldırıp yeniden kurmak, ki o da oturumu ve yerel tercihleri siler.
Yayınlamadan önce doğrula:

```bash
"$ANDROID_SDK/build-tools/36.0.0/apksigner.bat" verify --print-certs <apk> | grep -i "SHA-256"
```

v0.1.3+4 ve v0.2.0+5 için bu değer
`6da57755e82f50e0804010df82bed862e2813a4ba433be72741e4c8e821915bb`.
Değişmişse yayınlama, önce sebebini bul.

---

## Durum

### Çalışan

- **Kort kullanım ölçümü** — konsol > Metrikler altında "Halka açık kortlar"
  bölümü: kortta olan kişi, tekil kullanıcı, alınan/oynanan saat, gelmeme
  oranı, konum doğrulama oranı, en yoğun saat, kort kırılımı. 7/30/90 gün
  penceresi. Belediye görüşmesinin gövdesi bu.
  **`0041` çalıştırılmadan hata gösterir** (bilerek — "0 kutu" göstermek
  sistem kullanılmamış gibi okunurdu).

  Gelmeme oranının paydasında **iptaller yok**: iptal cezasız ve teşvik
  edilen davranış, onu gelmeme gibi saymak sistemi doğru kullanan kişiyi
  kötü gösterirdi.

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
listesinden ayrıntıya `Navigator.push` ile geçiliyor (courts'un kort
listesi/ayrıntısı deseninin aynısı — ayrıntı ekranının da adlı bir rotası
yok, ikisi de tutarlı). Yönetici olan kişi (`SwanAccess.isTurfManagerOf`)
aynı ekranda fazladan bir dokunma kontrolü görüyor.

Sahalar courts gibi **elle ekleniyor** (konsol), yöneticisi de yalnızca
platform yöneticisinin ürettiği davet koduyla atanıyor — işletme kendi
kaydolamıyor.

**"Bu saati istiyorum" (0039 + 0040) — bağlayıcı rezervasyon değil, sohbet.**
Gerçek boşluk şuydu: müşteri telefonla arar, görevli sözlü "tamam" der,
uygulamayı işaretlemeyi unutur, pano bayatlar. Çözüm iki taraflı kilitli
rezervasyon **değil**: `request_turf_slot` RPC'si oyuncunun ağzından sahanın
aktif yöneticilerine **gerçek bir doğrudan mesaj** gönderiyor (0040), iki
taraf var olan `/mesajlar` ekranından anlaşıyor, yönetici kesinleşince
`markOccupied` ile hücreyi kendisi işaretliyor.

`turf_slot_requests` tablosu duruyor ama artık iki iş yapıyor: şeritte
"İstendi" durumunu göstermek ve **aynı kişinin aynı hücreye tekrar dokununca
ikinci mesaj göndermesini engellemek** (unique kısıt + idempotent RPC).

Uygulama hiçbir zaman "onaylandı" demiyor — bu bilinçli: iki taraflı kilit,
courts'taki yarış durumu problemini gerçek parayla geri açardı (iki kişi aynı
saati isteyip yönetici ikisine de "tamam" derse sorumluluk SwanSport'a
kalırdı). Yöneticisi atanmamış sahada RPC hata veriyor — mesaj gidecek kimse
yokken "gönderildi" demek kullanıcıyı yanıltırdı.

**Doğrudan mesajlar 0040'a kadar hiç bildirim üretmiyordu.**
`NotificationService.send` yalnızca `direct_messages`'a satır atıyordu;
`notifications`'a hiçbir şey yazılmadığı için push da gitmiyordu — birine
mesaj attığında karşı taraf ancak uygulamayı kendi açarsa görüyordu. Tek
istisna `send_club_message`'ti (bildirimi elle yazıyordu). 0040 bunu
`trg_notify_direct_message` tetikleyicisine taşıdı: artık **tek kaynak**
tetikleyici, `send_club_message`'in elle yazan satırı kaldırıldı (ikisi
birden kalsaydı kulüp mesajlarında çift bildirim olurdu).

Migration'lar **0038'e kadar canlıda kurulu** (2026-08-30 doğrulandı): mali
defter sayfalaması, yoklama denetim izi, etkinlik katılım onayı, malzeme
ilanları, halka açık kortlar (çift dokunuş düzeltmesiyle), kort partneri
arama ve halı saha doluluk panosu şemada var.
`0039_turf_slot_requests.sql` ve `0040_dm_notify_and_turf_chat.sql`
**henüz sürülmedi** — sırayla çalıştırılmalı (0039 `turf_occupancy_grid`'i
yeniden yazıyor, 0040 `request_turf_slot`'u). Yeni migration yazarken
numarayı 0041'den sürdür.

Web dağıtımı 2026-08-30'da yapıldı; canlı derleme kort partneri arama ve
halı saha doluluk panosunu içeriyor.

### Yarım / doğrulanmamış

> **Migration durumu** (2026-09-01, kullanıcı 0040 ve 0041'i çalıştırdı)
>
> | Migration | Durum | Nasıl doğrulandı |
> |---|---|---|
> | `0039` | Uygulandı | `turf_slot_requests` tablosu REST'ten okunuyor |
> | `0041` | Uygulandı | `court_usage_stats` anon'a **401 permission denied** veriyor — fonksiyon var, izin doğru kapalı (yok olsaydı 404 gelirdi) |
> | `0040` | **Doğrulanmadı** | Yalnızca fonksiyon + tetikleyici içeriyor, ikisi de anon'a görünmez |
> | `0042` | **Çalıştırılmadı** | DM'lerin canlı akması buna bağlı — çalıştırılmadan mesajlar yine yenilemeyle geliyor |
> | `0043` | **Çalıştırılmadı** | Bildirim aç/kapa'nın `42501` vermesini düzeltiyor; çalıştırılmadan aynı telefonda hesap değiştirmiş kullanıcı bildirim açamıyor |
>
> `0040`'ı doğrulamak için `tools/verify_0040.sql`'i SQL Editor'e yapıştır:
> tetikleyicinin varlığını, `send_club_message`'in elle bildirim yazmayı
> bıraktığını ve hiçbir fonksiyonda çift imza kalmadığını (HTTP 300 tuzağı)
> kontrol eder.
>
> Hepsi idempotent; emin değilsen tekrar çalıştır, zararı yok.

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
- **Halı saha doluluk panosu** — şema canlıda (0038), web dağıtıldı. Ama
  **konsoldan hiç saha eklenmedi**; saha eklenip yönetici daveti redeem
  edilmeden ekranın düzenleme tarafı hiç test edilemez.
- **"Bu saati istiyorum" → sohbet** — kod ve testler hazır,
  `0039_turf_slot_requests.sql` ve `0040_dm_notify_and_turf_chat.sql`
  **canlıda çalıştırılmadı**, mobil derleme dağıtılmadı. Sırayla
  çalıştırılmalı (0039 `turf_occupancy_grid`'i dönüş tipi değiştiği için
  `drop` edip yeniden yazıyor, 0040 `request_turf_slot`'u sohbet açacak
  şekilde değiştiriyor).
- **Doğrudan mesaj bildirimi (0040)** — tetikleyici yazıldı ama **hiç
  denenmedi**. Sürüldükten sonra iki hesapla kontrol et: A'dan B'ye mesaj →
  B'ye push düşmeli. Ayrıca kulüp adına gönderilen mesajda **çift bildirim
  gelmediğini** doğrula (`send_club_message`'in elle yazan satırı kaldırıldı,
  ama canlıda eski sürüm kalmışsa iki bildirim gelir).

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
