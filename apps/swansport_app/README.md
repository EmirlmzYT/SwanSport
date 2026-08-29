# SwanSport

Spor kulübü yönetim ve spor ağı uygulaması. Tek koddan **web** ve **Android**
çalışır; veri katmanı **Supabase** (PostgreSQL) üzerindedir.

## Yapı

```
lib/
  app/            uygulama iskeleti — bootstrap, rotalar, ortam, paylaşılan widget'lar
  features/       özellik başına: data/ (servis + provider), presentation/ (ekran)
```

Durum yönetimi **Riverpod**. Ekranlar `features/<ad>/presentation/` altındadır.

**Veri katmanı bu uygulamada değil.** Supabase sorguları, satır modelleri ve
provider'lar `packages/swansport_data` paketindedir; masaüstü konsolu da aynı
paketi kullanır, böylece bir sorgu tek yerde durur:

```dart
import 'package:swansport_data/swansport_data.dart';
```

Paket arayüze bağlanmaz — `IconData`, `Color`, widget ve tema orada yer almaz.
Kategori ikonu/rengi gibi sunum sabitleri uygulamanın `presentation/` klasöründe
kalır (örnek: `features/performance_analytics/presentation/test_categories.dart`).

Ortak paketler depo kökündedir (`packages/`): `swansport_data`,
`swansport_design_system`, `swansport_core`, `swansport_models`,
`swansport_branch_engine`.

## Gereksinimler

- Flutter 3.44+ / Dart 3.12+
- Bir Supabase projesi (URL + anon anahtar)

## Ortam yapılandırması

Anahtarlar depoya girmez; `--dart-define-from-file` ile verilir.
`env/dev.json` dosyası `.gitignore`'dadır:

```json
{
  "SUPABASE_URL": "https://<proje>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon veya sb_publishable_ anahtar>"
}
```

İki giriş noktası vardır:

| Dosya | `APP_ENV` | Hata ayıklama araçları |
|---|---|---|
| `lib/main_development.dart` | development | açık |
| `lib/main_production.dart` | production | kapalı |

## Çalıştırma

```bash
flutter pub get
flutter run -t lib/main_development.dart --dart-define-from-file=env/dev.json
```

## Derleme

```bash
# Web
flutter build web --release -t lib/main_production.dart \
  --dart-define-from-file=env/prod.json

# Android
flutter build apk --release --split-per-abi -t lib/main_production.dart \
  --dart-define-from-file=env/prod.json
```

### Play Store imzası

İlk Play Store yüklemesinden önce, `android/` klasöründe kendi yayın anahtarını
oluştur ve güvenli bir yerde yedekle. Anahtar kaybolursa uygulamanın sonraki
sürümleri aynı uygulama kimliğiyle yayımlanamaz.

```bash
cd android
keytool -genkey -v -keystore swansport-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias swansport
```

Ardından `android/key.properties` oluştur:

```properties
storeFile=swansport-release.jks
storePassword=<mağaza-parolası>
keyPassword=<anahtar-parolası>
keyAlias=swansport
```

Bu dosya ve `.jks` anahtarı git tarafından izlenmez. İkisini de sohbete ya da
depoya koyma.

## Ortam davranışı

**Development** — Supabase yapılandırılmamışsa ya da erişilemiyorsa uygulama
sabit örnek veriye (fixture) düşer; backend olmadan ekran geliştirilebilir.

**Production** — fixture'a **düşmez**. Backend'e ulaşılamazsa bağlantı hatası
ekranı ve "tekrar dene" gösterilir. Sahte veriyi gerçek sanmak, boş ekran
görmekten daha kötüdür.

Demo rol değiştirici de yalnızca `enableDebugTools` açıkken görünür.
`lib/app/config/app_environment.dart` bu bayrağı taşır.

## Veritabanı

Şema `supabase/migrations/` altında, numaralı ve idempotent dosyalarda durur.
Kurulum ve yeni migration ekleme kuralları: [`../../supabase/README.md`](../../supabase/README.md)

## Test

```bash
flutter analyze
flutter test
```

## Dağıtım

Web sürümü **Cloudflare Pages** üzerinde:

```bash
npx wrangler pages deploy build/web --project-name=swansport
```

`functions/api/` altında iki Pages Function çalışır:

- `rss.js` — haber akışı için RSS köprüsü (tarayıcıdan CORS engelini aşar)
- `push.js` — web-push gönderimi (VAPID imzalama + yük şifreleme)

Push gönderimi için Pages ortam değişkenleri gerekir: `PUSH_SECRET`,
`VAPID_PUBLIC`, `VAPID_PRIVATE`, `VAPID_SUBJECT`.

## PWA

`web/manifest.json` uygulamayı telefona kurulabilir hale getirir.
Bildirim service worker'ı `web/push-sw/sw.js` altında ayrı bir kapsamda
çalışır; Flutter'ın kendi service worker'ına dokunmaz.
