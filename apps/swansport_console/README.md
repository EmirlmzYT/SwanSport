# SwanSport Konsol

Kulüp ve platform yönetimi için **masaüstü web** arayüzü. Mobil uygulamayla
aynı Supabase projesini, aynı kullanıcıları ve aynı RLS'i kullanır.

## Neden ayrı uygulama?

Mobil uygulamanın 52 ekranı telefon için tasarlandı — hepsi ~540px genişliğe
sığacak şekilde ortalanmış. Yönetim işi bunun tersini istiyor: geniş tablolar,
çoklu seçim, yan yana paneller, klavye. Aynı ekranı ikisine birden uydurmak
ikisini de bozardı.

Veri katmanı paylaşılıyor (`packages/swansport_data`), arayüz paylaşılmıyor.

## Fixture modu yok

Mobil uygulama, geliştirme ortamında backend'e ulaşamazsa örnek veriye düşer.
Konsol **düşmez**. Burada yapılan iş okumak değil yönetmek: sahte bir kadroda
toplu düzenleme yapmak ya da sahte bir faturayı "ödendi" işaretlemek, boş
ekran görmekten çok daha kötüdür. Bağlantı yoksa her ortamda hata gösterilir.

## Çalıştırma

```bash
flutter run -d chrome -t lib/main_development.dart --dart-define-from-file=env/dev.json
```

## Derleme

```bash
flutter build web --release -t lib/main_production.dart --dart-define-from-file=env/prod.json
```

## Dağıtım

Konsol, mobil uygulamayla **aynı origin altında** `/konsol/` yolunda yayınlanır.

Sebebi oturum: ayrı origin ayrı `localStorage` demek, o da uygulamada giriş
yapan kullanıcının konsolda ikinci kez giriş yapması demekti. Aynı origin
altında Supabase oturumu ikisi arasında paylaşılıyor — bir kez giriş, iki
yüzey.

İki derleme birleştirilip tek proje olarak gönderilir:

```bash
cd apps/swansport_app && flutter build web --release -t lib/main_production.dart --dart-define-from-file=env/prod.json
```
```bash
cd apps/swansport_console && MSYS_NO_PATHCONV=1 flutter build web --release -t lib/main_production.dart --dart-define-from-file=env/prod.json --base-href=/konsol/
```

`MSYS_NO_PATHCONV=1` yalnızca Git Bash için gerekli: `/konsol/` değerini
Windows yoluna (`C:/Program Files/Git/konsol/`) çevirip derlemeyi durduruyor.
PowerShell'de bu öneke gerek yok.
```bash
cp -r apps/swansport_console/build/web apps/swansport_app/build/web/konsol
```
```bash
cp apps/swansport_app/web/_redirects apps/swansport_app/build/web/_redirects
```
```bash
cd apps/swansport_app && npx wrangler pages deploy build/web --project-name=swansport --branch=main
```

Dikkat edilecek üç şey:

1. **`--base-href=/konsol/` şart.** Yoksa konsol varlıklarını kökten arar ve
   boş ekran açılır.
2. **`_redirects` elle kopyalanır.** Flutter alt çizgiyle başlayan dosyaları
   `build/web`'e taşımıyor.
3. **`_redirects` içinde konsol kuralı önce gelir.** Cloudflare ilk eşleşeni
   uygular; genel kural üstte olursa `/konsol/sporcular` isteği mobil
   uygulamanın index.html'ini döndürür.

## Yapı

```
lib/
  app/
    console_bootstrap.dart   Supabase başlatma, bağlantı hatası ekranı
    console_app.dart         MaterialApp.router
    console_router.dart      go_router; oturum yönlendirmesi, modül koruması
    modules/
      console_module.dart    ConsoleAudience, ConsoleAccess, ConsoleModule
      module_registry.dart   kConsoleModules — tek modül listesi
    shell/                   kenar çubuğu, üst bar, dar ekran uyarısı
    theme/console_theme.dart masaüstü yoğunluk ölçekleri
  features/                  modül ekranları
```

### Modül eklemek

`module_registry.dart` içindeki `kConsoleModules` listesine bir satır. Kenar
çubuğu ve yönlendirici aynı listeyi okuduğu için menüde görünüp açılmayan
(ya da tersi) bir modül oluşmaz.

### Yeni kitle eklemek

`ConsoleAudience` enum'unda `federation`, `accountant`, `marketplace` yuvaları
hazır bekliyor — `ConsoleAccess.allows` içinde bugün `false` dönüyorlar.
Sırası gelince orayı doldurup listeye modül eklemek yeterli. Bu enum yalnızca
arayüz gruplandırmasıdır; veri modeli değildir, yeni tablo gerektirmez.

## Yetki

Kenar çubuğunda modül gizlemek **güvenlik değildir** — kullanıcı adresi
doğrudan yazabilir. `_Guarded` sarmalayıcısı yetkisi olmayana anlaşılır bir
mesaj gösterir, ama veriyi koruyan şey Supabase'deki RLS politikalarıdır.
Konsol anon anahtarla çalışır; tarayıcıya service-role anahtarı konmaz.
