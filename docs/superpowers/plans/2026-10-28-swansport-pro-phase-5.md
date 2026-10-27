# SwanSport Pro — Faz 5 Uygulama Planı ve Mevcut Durum Envanteri

**Tarih:** 2026-10-28  
**Başlangıç Commit:** `9e88831 feat(pro): complete phase four operations`  
**Hedef:** SwanSport Pro mobil ve operasyonel bildirim altyapısının kurulması, iki uygulama arasında (`social` vs `pro`) bildirim izolasyonu, merkezi hedef yönlendirme politikası, Cloudflare Pages Function hedef duyarlılığı, Pro Gelen Kutusu (`/gelen-kutusu`), derin bağlantı (deep-link) matrisi, profesyonel bildirim tercihleri ve güvenli mobil dağıtım (APK/AAB/IPA) hatlarının hazırlanması.

---

## 1. Mevcut Durum Envanteri

### 1.1 Mevcut `push_subscriptions` Şeması
- **Tanım Yeri:** `supabase/migrations/0015_push.sql`, `0029_fcm_push.sql`, `0043_push_register_rpc.sql`, `20261025042446_push_delivery_tracking.sql`.
- **Kolonlar:**
  - `id uuid primary key default gen_random_uuid()`
  - `profile_id uuid not null references public.profiles(id) on delete cascade`
  - `endpoint text not null unique` (FCM token veya Web Push endpoint)
  - `p256dh text not null`
  - `auth text not null`
  - `user_agent text`
  - `kind text default 'fcm'`
  - `created_at timestamptz not null default now()`
  - `delivery_revision bigint not null default 1`
- **Tetikleyici:** `push_registration_revision` (`before update on public.push_subscriptions`)
  - `_push_registration_revision()` fonksiyonu kimlik veya cihaz bilgisi değiştiğinde `delivery_revision` değerini artırır.
- **RLS:** `push_own` politikası (`profile_id = auth.uid()`).
- **Eksiklik / Hedef:** Tabloda `app_target` kolonu (`'social'`, `'pro'`) bulunmamaktadır. Varsayılan `'social'` olmalıdır.

### 1.2 `register_push_subscription` RPC İmzası
- **Tanım Yeri:** `supabase/migrations/0043_push_register_rpc.sql:31-75`.
- **Mevcut İmza:** `register_push_subscription(p_endpoint text, p_kind text default 'fcm', p_p256dh text default null, p_auth text default null, p_user_agent text default null) returns void`.
- **Güvenlik:** `security definer`, `public` ve `anon` revoke edilmiş, `authenticated` grant verilmiş. Cihaz adresini (`p_endpoint`) o anki `auth.uid()` hesabına devreder.
- **Gereksinim:** `p_app_target text default 'social'` parametresi eklenmeli (`check (p_app_target in ('social', 'pro'))`). PostgREST HTTP 300 belirsizliğini önlemek için eski 5 parametreli fonksiyon `drop function if exists` ile kaldırılıp tek 6 parametreli (varsayılan değerli) imza bırakılmalı.

### 1.3 `push_subscription_state` Fonksiyonu
- **Tanım Yeri:** `supabase/migrations/0043_push_register_rpc.sql:84-105`.
- **Mevcut İmza:** `push_subscription_state(p_endpoint text) returns text`.
  - Döndürdüğü durumlar: `'no_session'`, `'missing'`, `'mine'`, `'other_account'`.
- **Gereksinim:** Hedef uygulamayı (`p_app_target text default 'social'`) dikkate almalıdır.

### 1.4 `push_delivery_attempts` ve Retry Sistemi
- **Tanım Yeri:** `supabase/migrations/20261025042446_push_delivery_tracking.sql`.
- **Tablo Yapısı:**
  - `id uuid primary key`
  - `notification_id uuid not null references public.notifications(id) on delete cascade`
  - `profile_id uuid not null references public.profiles(id) on delete cascade`
  - `subscription_id uuid references public.push_subscriptions(id) on delete set null`
  - `subscription_revision bigint not null`
  - `status text check (status in ('pending','in_flight','accepted','retry','failed','unknown','skipped','expired'))`
  - `attempt_count int default 0 check (attempt_count between 0 and 3)`
  - `request_id bigint`
  - `last_attempt_at timestamptz`
  - `next_attempt_at timestamptz default now()`
  - `expires_at timestamptz not null`
  - `last_outcome text`
  - `unique(notification_id, subscription_id)`
- **Güvenlik & Gizlilik:** Token, gövde, sır saklanmaz; platform admin hariç okuma kapalıdır.
- **İşleyiş:** `push_on_notification()` tetikleyicisi bildirim geldiğinde delivery attempt oluşturur ve `_dispatch_push_delivery()` ile `net.http_post` çağrısı yapar. `process_push_deliveries()` cron/backend işi yanıtları inceler.
  - Geçici sağlayıcı retlerinde (429, 500, 503) maksimum 3 deneme (`retry`).
  - Belirsiz sonuçlarda (`unknown`) tekrar gönderim yapılmaz.
  - Token geçersizse (`gone = true`, 404 UNREGISTERED) abonelik silinir.
- **Gereksinim:** `push_delivery_attempts` tablosuna `app_target text not null check (app_target in ('social', 'pro'))` eklenmeli; `_dispatch_push_delivery` aşamasında aboneliğin `app_target` ve bildirim politikası yeniden doğrulanmalı; uyumsuzluk durumunda `status = 'skipped', last_outcome = 'target_mismatch'` yapılmalıdır.

### 1.5 Cloudflare Push Göndericisi
- **Tanım Yeri:** `apps/swansport_app/functions/api/push.js`.
- **Mevcut Yapı:** `PUSH_SECRET`, `FCM_SERVICE_ACCOUNT`, `VAPID_*` ortam değişkenlerini kullanır. Tek bir FCM service account ile Google OAuth2 token üretir.
- **Gereksinim:** `job.appTarget` parametresini almalı (`'social'` veya `'pro'`). `pro` hedefi için `env.PRO_FCM_SERVICE_ACCOUNT`, `social` hedefi için `env.FCM_SERVICE_ACCOUNT` seçilmeli. Bilinmeyen veya eksik hedef reddedilmeli (`400`). Sırlar yanıtlarda veya loglarda yer almamalıdır.

### 1.6 SwanSport Push İstemcisi
- **Tanım Yeri:** `packages/swansport_data/lib/src/push_subscription_service.dart` / `pushRegistrationServiceProvider`.
- **Mevcut Durum:** Hedef ayrımı olmaksızın `register_push_subscription` çağrısı yapar.
- **Gereksinim:** `PushAppTarget` enum (`social`, `pro`) eklenmeli. SwanSport App daima `PushAppTarget.social`, SwanSport Pro daima `PushAppTarget.pro` göndermeli. Oturum sonlanmasında state temizlenmeli.

### 1.7 Pro Router ve Mevcut Gelen Kutusu Placeholder'ı
- **Tanım Yeri:** `apps/swansport_pro/lib/app/pro_router.dart:60-68`.
- **Mevcut Durum:** `/gelen-kutusu` rotası `ProPlaceholderScreen(title: 'Gelen Kutusu')` döndürmektedir.
- **Gereksinim:** Gerçek `SharedProInboxScreen` ile değiştirilmeli; okundu/okunmadı filtreleme, sayfalama, hata/boş durum, güvenli HTML-kaçışlı metin renderı ve allowlist'e tabi Pro rotalarına yönlendirme eklenmelidir.

### 1.8 Android / iOS Yapılandırmaları ve Güvenlik Kapıları
- **Android:**
  - `apps/swansport_pro/android/app/build.gradle.kts`: `applicationId = "com.swansport.pro"`.
  - `google-services.json` depoya eklenmez; CI ortamında `PRO_ANDROID_GOOGLE_SERVICES_BASE64` secret'ından üretilir.
- **iOS:**
  - `apps/swansport_pro/ios/Runner.xcodeproj`: Bundle ID `com.swansport.pro`.
  - `GoogleService-Info.plist` depoya eklenmez.
  - Önizleme / test sürümlerinde `Push-disabled unsigned iOS preview IPA`: Native APNs entitlement ve Firebase kaydı devre dışı olmalıdır (`tools/guard_ios_firebase_registration.py`, `tools/configure_ios_firebase.py`).
  - İmzalı sürümde `PRO_IOS_GOOGLE_SERVICE_INFO_BASE64` ve Apple sertifikaları ile tam APNs entegrasyonu sağlanır.

---

## 2. 42 Bildirim Türü ve Hedef Sınıflandırma Matrisi

Sistemdeki 42 adet bildirim türünün (`0118_match_following_notifications.sql:215-256`) hedef ve yönlendirme sözleşmesi:

| # | Bildirim Türü (`kind`) | Hedef Kategori | Açıklama | SwanSport Sosyal Rota | SwanSport Pro Rota |
|---|------------------------|----------------|----------|-----------------------|--------------------|
| 1 | `message` | `social` | Doğrudan mesajlaşma | `/mesajlar` | — (Pro'ya iletilmez) |
| 2 | `follow` | `social` | Sosyal takip | `/bildirimler` | — (Pro'ya iletilmez) |
| 3 | `mention` | `social` | Gönderi bahsi | `/akis` | — (Pro'ya iletilmez) |
| 4 | `post_repost` | `social` | Gönderi yeniden paylaşımı | `/akis` | — (Pro'ya iletilmez) |
| 5 | `post_quote` | `social` | Gönderi alıntılama | `/akis` | — (Pro'ya iletilmez) |
| 6 | `partner_request` | `social` | Partner arama talebi | `/partner-ara` | — (Pro'ya iletilmez) |
| 7 | `partner_request_accepted` | `social` | Partner talebi kabulü | `/partner-ara` | — (Pro'ya iletilmez) |
| 8 | `offer` | `social` | Sponsorluk / bireysel teklif | `/bildirimler` | — (Pro'ya iletilmez) |
| 9 | `achievement` | `social` | Sporcu başarı rozeti | `/performance-analytics` | — (Pro'ya iletilmez) |
| 10 | `referee_assignment` | `pro` | Hakem görev ataması | `/hakem/gorevler` | `/operasyon/hakem-gorevleri` |
| 11 | `expense_approval` | `pro` | Kulüp harcama onayı talebi | `/mali-isler` | `/operasyon/muhasebe` |
| 12 | `expense_rejected` | `pro` | Harcama ret bildirimi | `/mali-isler` | `/operasyon/muhasebe` |
| 13 | `commitment_due` | `pro` | Mali taahhüt vade uyarısı | `/mali-isler` | `/operasyon/mali-taahhutler` |
| 14 | `account_negative` | `pro` | Negatif bakiye bildirimi | `/mali-isler` | `/operasyon/muhasebe` |
| 15 | `bank_unmatched` | `pro` | Eşleşmeyen banka hareketi | `/mali-isler` | `/operasyon/banka-mutabakati` |
| 16 | `period_closed` | `pro` | Muhasebe dönem kapanışı | `/mali-isler` | `/operasyon/donem-kapanisi` |
| 17 | `period_blocked` | `pro` | Kilitli dönem işlem denemesi | `/mali-isler` | `/operasyon/donem-kapanisi` |
| 18 | `turf_slot_request` | `pro` | Saha rezervasyon talebi | `/halisahalar` | `/operasyon/tesis-takvim` |
| 19 | `turf_field` | `pro` | Tesis / saha durum değişikliği | `/halisahalar` | `/operasyon/tesis` |
| 20 | `turf_manager` | `pro` | Saha yöneticisi yetki devri | `/halisahalar` | `/operasyon/tesis` |
| 21 | `court_waitlist` | `pro` | Kort bekleme listesi bildirimi | `/saha-islemlerim` | `/operasyon/tesis-takvim` |
| 22 | `turf_delegation` | `pro` | Saha operasyon delegasyonu | `/saha-islemlerim` | `/operasyon/tesis-gorevleri` |
| 23 | `store_decision` | `pro` | Kulüp mağaza / ürün kararı | `/magaza-basvuru` | `/operasyon/platform` |
| 24 | `moderation` | `pro` | Platform içerik moderasyonu | `/pazaryeri` | `/operasyon/platform` |
| 25 | `match_live` | `both` | Canlı maç bildirimi | `/canli-mac/:id` | `/operasyon/hakem-canli/:id` (veya `/gelen-kutusu`) |
| 26 | `match_result` | `both` | Resmi maç sonucu | `/resmi-sonuc` | `/operasyon/federasyon-maclar` |
| 27 | `fee` | `both` | Kulüp aidat bildirimi | `/aidatlarim` | `/operasyon/muhasebe` |
| 28 | `fee_reminder` | `both` | Aidat ödeme hatırlatması | `/aidatlarim` | `/operasyon/muhasebe` |
| 29 | `payment` | `both` | Tahsilat / ödeme makbuzu | `/finans` | `/operasyon/muhasebe` |
| 30 | `donation` | `both` | Bağış / fon katkısı | `/bagis` | `/operasyon/muhasebe` |
| 31 | `attendance` | `both` | Yoklama durumu bildirimi | `/attendance` | `/operasyon/yoklama` |
| 32 | `attendance_reminder` | `both` | Yoklama hatırlatması | `/attendance` | `/operasyon/yoklama` |
| 33 | `event` | `both` | Kulüp / takım takvim etkinliği | `/calendar` | `/gelen-kutusu` |
| 34 | `announcement` | `both` | Kulüp / federasyon duyurusu | `/announcements` | `/gelen-kutusu` |
| 35 | `document` | `both` | Belge yükleme bildirimi | `/documents` | `/gelen-kutusu` |
| 36 | `documents` | `both` | Toplu evrak işlemi | `/documents` | `/gelen-kutusu` |
| 37 | `document_expiry` | `both` | Belge / lisans süre sonu | `/documents` | `/gelen-kutusu` |
| 38 | `support` | `both` | Destek talebi güncellemesi | `/destek` | `/gelen-kutusu` |
| 39 | `eligibility` | `both` | Sporcu lisans / uygunluk | `/athletes` | `/gelen-kutusu` |
| 40 | `training_session` | `both` | Antrenman oturumu başlangıcı | `/antrenman-oturumu` | `/operasyon/antrenmanlar` |
| 41 | `training_result` | `both` | Antrenman performans özeti | `/antrenman-sonuc` | `/operasyon/antrenmanlar` |
| 42 | `application` | `both` | Kulüp / üyelik başvurusu | `/basvurular` | `/gelen-kutusu` |
| * | Bilinmeyen (`unknown`) | `social` (fail-closed) | Beklenmeyen / yeni eklenen | `/bildirimler` | — (Pro'ya iletilmez) |

---

## 3. Uygulama Adımları ve Görev Dağılımı

### Görev 1: Plan ve Mevcut Durum Envanteri (Tamamlandı)
- `docs/superpowers/plans/2026-10-28-swansport-pro-phase-5.md` oluşturuldu.

### Görev 2 & 3: `app_target` Push Migration'ı ve Merkezi Hedef Politikası
- Migration dosyası: `supabase/migrations/20261028000000_push_app_target.sql`.
  - `push_subscriptions.app_target` (`social`, `pro`, varsayılan `social`).
  - `push_registration_revision` tetikleyicisine `app_target` değişikliği eklendi (`delivery_revision + 1`).
  - `push_delivery_attempts.app_target` kolonu eklendi.
  - `_notification_target_policy(kind text)` ile 42 türün hedef sınıflandırması ve fail-closed `social` kuralı.
  - `pro_push_route(kind text, entity text)` ile tipli Pro rotaları ve `/gelen-kutusu` fallback'i.
  - `push_on_notification()` tetikleyicisinde hedefe uygun aboneliklerin filtrelenmesi.
  - `_dispatch_push_delivery(id uuid)` içinde hedef kontrolü (`status = 'skipped', last_outcome = 'target_mismatch'`).
  - `register_push_subscription(p_endpoint, p_kind, p_p256dh, p_auth, p_user_agent, p_app_target)`: tek imza, `authenticated` erişimi, `public`/`anon` revoke.
  - `push_subscription_state(p_endpoint, p_app_target)` fonksiyonu.
- SQL Testleri: `tools/push_target_sql_test.mjs` (42 türün hedef ayrımı, retry hedef doğrulaması, hedef uyumsuzluğu durumunda skipped testi).

### Görev 4: Cloudflare Push Göndericisi Hedef Duyarlılığı
- `apps/swansport_app/functions/api/push.js` güncellemesi:
  - `job.appTarget` doğrulaması (`'social'` veya `'pro'`). Bilinmeyen hedefte 400.
  - `PRO_FCM_SERVICE_ACCOUNT` vs `FCM_SERVICE_ACCOUNT` seçimi.
  - Pro bildirimlerinde `channel_id: 'swansport_pro_default'`.
  - Hiçbir sırrın veya token'ın loglara / yanıta sızmaması.
- Node testleri: `tools/push_delivery_test.mjs` içinde hedef ayrımı ve kimlik doğrulama testleri.

### Görev 5: Ortak Veri Katmanında Hedefli Push Sözleşmesi
- `packages/swansport_data/lib/src/push_target.dart`: `enum PushAppTarget { social, pro }`.
- `PushSubscriptionService`: Hedefi RPC'ye aktarma, hesap değişiminde state temizleme.
- Birim testleri: `packages/swansport_data/test/push_target_test.dart`.

### Görev 6: SwanSport Pro Push İstemcisi
- `apps/swansport_pro/pubspec.yaml`: `firebase_core` ve `firebase_messaging` eklenmesi.
- `tools/pro_app_contract_test.py`: Pro uygulamasının bağımsız yapısını korurken Firebase paketlerine izin verilmesi, ancak şube motorunun (`swansport_branch_engine`) ve sırların repoya sızmasının engellenmesi.
- Web/önizleme derlemelerinde push yapılandırması olmadan graceful fallback.

### Görev 7: Pro Gelen Kutusu (`/gelen-kutusu`)
- `packages/swansport_pro_features/lib/src/inbox/shared_pro_inbox_screen.dart`:
  - Okundu / okunmadı filtresi.
  - Sayfalama, yenileme, boş durum, hata durumu ve tekrar deneme.
  - Tipli Pro rotalarına tıklama yönlendirmesi.
  - Kullanıcı girdilerinin güvenli kaçışı.
- `apps/swansport_pro/lib/app/pro_router.dart`: `/gelen-kutusu` rotasının `SharedProInboxScreen` ile bağlanması.

### Görev 8: Pro Deep-Link Yönlendirme Matrisi
- Tipli rota ayrıştırıcı ve doğrulayıcı (`ProNotificationRouteHandler` / `pro_router.dart`).
- Bilinmeyen veya parametresi geçersiz olan linklerde `/gelen-kutusu` fallback'i.
- `tools/check_push_routes.py` kontrolünün 42 rota ile başarıyla geçmesi.

### Görev 9: Bildirim Ayarları
- `apps/swansport_pro/lib/features/account/pro_account_screen.dart`:
  - Profesyonel bildirim tercihleri bölümü.
  - Sunucu tarafında `push_preferences` doğrulaması.
  - İzin reddinde bilgilendirici UI kartı.

### Görev 10: CI ve Dağıtım Hatları
- `.github/workflows/pro-mobile-release.yml`:
  - Android APK / AAB.
  - Push-disabled unsigned iOS preview IPA.
  - Push-enabled signed iOS release IPA.
  - Web release build.
  - SHA-256 sağlama toplamı dosyaları.
  - Firebase yapılandırma ve secret izolasyon testleri.

### Görev 11: Staging ve Cihaz Kabul Matrisi
- `docs/swansport-pro-device-acceptance-matrix.md`:
  - 19 maddelik fiziksel test senaryoları matrisi.
  - Henüz gerçek cihazda koşulmamış testlerin dürüstçe `BEKLİYOR` olarak işaretlenmesi.

### Görev 12: Test ve Doğrulama
- Paket içi analizler: `flutter analyze`, `flutter test`.
- Araç testleri: `npm test --prefix tools`, Python sözleşme testleri.
- Pro Web Release build doğrulaması.

### Görev 13: Rapor ve Commit Zinciri
- `docs/swansport-pro-phase-5-verification.md` raporu.
- Planlanan commit zinciri:
  1. `test(pro): define phase five notification contracts`
  2. `feat(push): target subscriptions by application`
  3. `feat(push): isolate professional delivery routing`
  4. `feat(pro): add professional notification inbox`
  5. `feat(pro): route professional push deep links`
  6. `ci(pro): add isolated mobile release pipelines`
  7. `docs(pro): verify phase five distribution readiness`
