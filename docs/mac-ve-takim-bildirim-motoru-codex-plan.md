# SwanSport — Maç & Takım Takip Bildirim Motoru (0118) ve iOS Bildirim Düzeltme Planı

Bu plan iki ana eksenden oluşur:
1. **IPA / iOS Bildirim Hattının Onarılması:** Kod, yerel iOS konfigürasyonu ve Cloudflare bildirim iletim katmanının iOS'a açılması.
2. **Kişiselleştirilmiş Maç & Takım Canlı Bildirim Motoru (0118):** Taraftar/veli/seyircilerin maç ve takımları takip ederek canlı gol/düdük/skor bildirimlerini telefonlarına alması.

---

## BÖLÜM 1: IPA / iOS BİLDİRİM HATTI ONARIMI

### 1.1. Tespit Edilen Kök Nedenler (Root Causes)
1. **Dart Katmanı Blokajı (`apps/swansport_app/lib/app/push/push_io.dart` L29):**
   - `bool get pushSupported => defaultTargetPlatform == TargetPlatform.android;` olarak sabitlenmiş.
   - iOS'ta uygulama açıldığında bildirim desteği `false` döndüğü için izin istenmiyor, token alınmıyor ve Supabase'e kaydedilmiyor.
2. **iOS Proje Eksikleri:**
   - `apps/swansport_app/ios/Runner/Info.plist`: `UIBackgroundModes` (`remote-notification`, `fetch`) eksik.
   - `apps/swansport_app/ios/Runner/Runner.entitlements`: Dosya mevcut değil; `aps-environment` yetkisi tanımlanmamış.
3. **Cloudflare İletim Katmanı (`apps/swansport_app/functions/api/push.js`):**
   - `sendFcm` fonksiyonunda iOS APNs için `apns.payload.aps` (`alert`, `sound: 'default'`, `badge: 1`) yükü eksik.
4. **CI / Dağıtım & Apple Kuralları:**
   - `.github/workflows/build_ios.yml` içinde `GoogleService-Info.plist` secret adımı bulunmuyor.
   - **Kritik Apple Kuralı:** Apple, ücretsiz bireysel Apple kimlikleriyle imzalanan (Sideloadly / AltStore) IPA'larda APNs bildirim sunucularını kapatır. Bildirimlerin canlıda çalışması için TestFlight veya Apple Developer Program ($99/yıl) sertifikası zorunludur.

### 1.2. Yapılacak Kod Düzeltmeleri
1. **`push_io.dart`:**
   - `pushSupported` iOS'u da kapsayacak:
     ```dart
     bool get pushSupported =>
         defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS;
     ```
   - `pushSubscribe()` içinde iOS için ses, rozet ve uyarı izinleri tam istenir.
2. **`Info.plist`:**
   ```xml
   <key>UIBackgroundModes</key>
   <array>
       <string>fetch</string>
       <string>remote-notification</string>
   </array>
   ```
3. **`Runner.entitlements`:**
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>aps-environment</key>
       <string>production</string>
   </dict>
   </plist>
   ```
4. **`functions/api/push.js`:**
   - FCM v1 çağrısına iOS APNs blokları eklenir:
     ```javascript
     apns: {
       payload: {
         aps: {
           alert: {
             title: job.title || 'SwanSport',
             body: job.body || '',
           },
           sound: 'default',
           badge: 1,
         },
       },
     },
     ```

---

## BÖLÜM 2: MAÇ & TAKIM TAKİP BİLDİRİM MOTORU (0118)

### 2.1. Veritabanı Şeması (`supabase/migrations/0118_match_following_notifications.sql`)

1. **`match_followers` Tablosu:**
   ```sql
   create table if not exists public.match_followers (
     match_id    uuid not null references public.official_matches(id) on delete cascade,
     profile_id  uuid not null references public.profiles(id) on delete cascade,
     notify_kickoff boolean not null default true,
     notify_score   boolean not null default true,
     notify_final   boolean not null default true,
     created_at     timestamptz not null default now(),
     primary key (match_id, profile_id)
   );
   alter table public.match_followers enable row level security;
   ```
2. **RLS Politikaları:**
   - Kullanıcı kendi takip kayıtlarını okur ve yazar (`profile_id = auth.uid()`).
3. **Yönetim RPC'leri:**
   - `toggle_match_follow(p_match_id uuid)`: Maçı takip et/bırak (atomik).
   - `get_match_follow_status(p_match_id uuid)`: Maçın takip edilip edilmediğini döner.
4. **Canlı Olay Tetikleyicisi (`trg_notify_match_followers`):**
   - 0112 hakem olay motoruna (`match_live_events`) veya maç durumu değişimine bağlanır.
   - Gol, sayı, set, maç başlangıcı (`period_start` / `first_half`) veya maç sonu (`match_ended`) olduğunda:
     * İlgili maçın `match_followers` listesini toplar.
     * İlgili maçın takımlarını/kulüplerini takip eden kullanıcıları (`follows` tablosu) toplar.
     * `notifications` tablosuna `kind = 'match_live'` satırları yazar.
     * Bu işlem, mevcut `push_on_notification` tetikleyicisi üzerinden anında push gönderimine dönüşür.
5. **`push_route` Güncellemesi:**
   - `'match_live'` türü `/canli-mac/<id>` rotasına yönlendirilir (41 mevcut eşleme kayıpsız korunur).
6. **Özellik Bayrağı & SSS:**
   - `live_match_notifications` ('admins', 'Canlı Maç & Takım Bildirimleri').
   - SSS kaydı `118` sıra numarasıyla eklenir.

---

## BÖLÜM 3: ORTAK VERİ KATMANI (`packages/swansport_data`)

1. **Saf Modeller (`packages/swansport_data/lib/src/match_following_models.dart`):**
   - `MatchFollowState`: `matchId`, `isFollowed`, `notifyKickoff`, `notifyScore`, `notifyFinal`.
2. **Servis & Açık Tipli Riverpod Sağlayıcıları (`packages/swansport_data/lib/src/match_following_service.dart`):**
   - `MatchFollowingService(this.client)`
   - `final Provider<MatchFollowingService> matchFollowingServiceProvider = ...`
   - `final AutoDisposeFutureProviderFamily<bool, String> isMatchFollowedProvider = ...`
   - `Future<bool> toggleFollow(String matchId)`
3. **Export:** `packages/swansport_data/lib/swansport_data.dart`.

---

## BÖLÜM 4: MOBİL ARAYÜZ ENTEGRASYONU (`apps/swansport_app`)

1. **Canlı Maç Detay Ekranı (`live_match_detail_screen.dart`):**
   - Üst çubukta (AppBar) veya skor tabelasının sağ üst köşesinde zarif `🔔 Bildirimleri Aç` ikonu / SwanPill butonu.
   - Dokunulduğunda haptic titreşim + renk `SwanPalette.accent` / `Icons.notifications_active_rounded` haline gelir.
   - Bildirim açıkken: *"Bu maçın gol ve sonuç bildirimlerini alacaksınız."* bilgi tostu.
2. **Canlı Skor Merkezi (`live_match_hub_screen.dart` / `feed_screen.dart`):**
   - Maç kartlarının kenarında takip durumu göstergesi.

---

## BÖLÜM 5: TESTLER VE DOĞRULAMA

1. **`tools/match_following_sql_test.mjs`:**
   - Takip ekleme/çıkarma RLS doğrulaması.
   - Hakem gol/başlama olayı girdiğinde `notifications` satırının atomik üretilmesi.
   - Gizlilik denetimi: Çocuk gizliliği maskeli adlarının korunması.
2. **Araç Kontrolleri:**
   - `python tools/check_migrations.py` (118 migration)
   - `python tools/check_faq.py` (44/44)
   - `python tools/check_push_routes.py` (42/42 kayıpsız)
   - `python tools/check_mobile_ui_tokens.py`
