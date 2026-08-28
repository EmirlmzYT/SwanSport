# SwanSport

Spor kulüpleri için yönetim platformu ve spor ağı. Kulüpler, federasyonlar,
antrenörler, sporcular, veliler ve platform yöneticileri için iki yüzey:

- **Mobil/web uygulaması** — sahada ve günlük kullanımda; sosyal akış, mesajlaşma,
  yoklama, aidat, doğrulama.
- **Masaüstü konsolu** — masa başında yönetim; yoğun tablolar, toplu işlemler,
  onay kuyrukları.

İkisi aynı Supabase projesini, aynı kullanıcıları ve aynı RLS politikalarını
kullanır. Veri katmanı paylaşılır, arayüz paylaşılmaz.

## Depo yapısı

```text
apps/swansport_app                 Mobil + web uygulaması (Android, Web)
apps/swansport_console             Masaüstü yönetim konsolu (yalnızca Web)
packages/swansport_data            Supabase veri katmanı — İKİ UYGULAMANIN ORTAK KAYNAĞI
packages/swansport_core            Ortam ve yapılandırma tipleri
packages/swansport_design_system   Renk paleti, tipografi, mobil bileşenler
packages/swansport_models          Paylaşılan değer tipleri
packages/swansport_branch_engine   Branş kuralları
supabase/migrations                Şema — tek yetkili kaynak, numaralı ve idempotent
supabase/seed                      Demo verisi
docs/                              Ürün ve mimari notları
```

**`swansport_data` kritik.** Sorgular, satır modelleri ve Riverpod
sağlayıcıları orada durur; hiçbir arayüz bağımlılığı yoktur. Bir sorguyu iki
uygulamada ayrı ayrı yazmak, zamanla birbirinden ayrılmaları demekti.

Kim neyi görebilir hesabı da orada: `SwanAccess`. Mobilde rota kümesine,
konsolda modül listesine çevrilir — ama hesabın kendisi tektir.

## Gereksinimler

- Flutter 3.44+ / Dart 3.12+
- Bir Supabase projesi (URL + anon anahtar)

## Kurulum

```bash
flutter pub get
```

Anahtarlar depoya girmez; `env/dev.json` ve `env/prod.json` gitignore'dadır:

```json
{
  "APP_ENV": "development",
  "APP_NAME": "SwanSport",
  "ENABLE_DEBUG_TOOLS": "true",
  "SUPABASE_URL": "https://<proje>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon veya sb_publishable_ anahtar>"
}
```

## Çalıştırma

```bash
cd apps/swansport_app && flutter run -t lib/main_development.dart --dart-define-from-file=env/dev.json
```
```bash
cd apps/swansport_console && flutter run -d chrome -t lib/main_development.dart --dart-define-from-file=env/dev.json
```

## Test ve analiz

```bash
flutter analyze packages/swansport_data apps/swansport_console apps/swansport_app
```
```bash
cd packages/swansport_data && flutter test
```
```bash
cd apps/swansport_console && flutter test
```

Mobil uygulamanın test paketinde bilinen bir sorun var: bir bölüm test,
Supabase istemcisi başlatılmadan ekran açtığı için başarısız oluyor
(`_instance._isInitialized`). Sayı uzun süredir sabit; düzeltmesi ortak bir
test kurulumu yazmayı gerektiriyor.

## Dağıtım

İki uygulama **tek Cloudflare Pages projesinde**, aynı origin altında yayınlanır:

- `https://swansport.pages.dev/` — uygulama
- `https://swansport.pages.dev/konsol/` — konsol

Aynı origin olması bir tercih: ayrı origin ayrı `localStorage` demek, o da
uygulamada giriş yapan kullanıcının konsolda ikinci kez giriş yapması demekti.
Aynı origin altında Supabase oturumu ikisi arasında paylaşılıyor.

Adımlar: [`apps/swansport_console/README.md`](apps/swansport_console/README.md)

`functions/` altında üç Pages Function çalışır:

| Dosya | İş |
|---|---|
| `api/rss.js` | Haber akışı köprüsü (tarayıcı CORS engelini aşar) |
| `api/push.js` | Web push gönderimi (VAPID imzalama + yük şifreleme) |
| `konsol/[[path]].js` | Konsolun derin bağlantıları |

## Veritabanı

Şema `supabase/migrations/` altında, numaralı ve idempotent dosyalarda.
Kurulum ve yeni migration kuralları: [`supabase/README.md`](supabase/README.md)

## Kurallar

- Widget'tan doğrudan Supabase çağırma; veri katmanı `swansport_data`'da.
- Yeni tabloya **RLS yaz**. Arayüzde düğme gizlemek güvenlik değildir.
- `security definer` fonksiyonlarda yetkiyi fonksiyonun içinde doğrula.
- Kullanıcı tarafından çağrılmaması gereken fonksiyonların iznini `public`,
  `anon` **ve** `authenticated` rollerinden kaldır — yalnızca son ikisinden
  almak yetmez, izin `PUBLIC`'ten miras alınır.
- Gizli anahtarları depoya koyma.

## Bilinen eksikler

- Android'de push bildirimi yok (FCM kurulmadı; web push çalışıyor)
- Release imzası için keystore üretilmedi — APK elden kurulur, Play Store'a
  yüklenemez
- Online kart ödemesi için ödeme kuruluşu entegrasyonu yok
- KVKK aydınlatma metni hukukçu tarafından yazılmalı
