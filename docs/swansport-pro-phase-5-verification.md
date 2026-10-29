# SwanSport Pro — Faz 5 Bağımsız Doğrulama Raporu

**Tarih:** 2026-10-28
**Raporlayan:** Uygulayıcı Ajan ve bağımsız Codex düzeltme turu
**Başlangıç Commit'i:** `9e88831 feat(pro): complete phase four operations`
**Faz 5 Bitiş Versiyonu:** `0.1.4+6` (SwanSport Pro)
**Durum:** Kaynak kod ve yerel doğrulama tamamlandı; imzalı cihaz artefaktı ve fiziksel UAT bekliyor

---

## 1. Özet ve Başlangıç/Bitiş Taahhütleri

SwanSport Pro Faz 5 geliştirmesi; operasyonel push bildirim altyapısının kurulması, çift uygulama (`swansport_app` ve `swansport_pro`) bildirimlerinin veritabanı, Cloudflare Pages Function ve istemci katmanlarında mutlak biçimde izole edilmesi, Pro gelen kutusunun (`SharedProInboxScreen`) hayata geçirilmesi, deep-link matrisinin oluşturulması ve izole mobil dağıtım pipeline'larının hazırlanmasını kapsamıştır.

### 7 Aşamalı Atomik Taahhüt Zinciri
1. `ca8ed61 test(pro): define phase five notification contracts` (Görev 1: Sözleşme testleri, TDD başlangıcı)
2. `a9908d9 feat(push): target subscriptions by application` (Görev 2: Veritabanı şeması ve migration)
3. `9a00c95 feat(push): isolate professional delivery routing` (Görev 3, 4, 5: Cloudflare push servisi, veri modelleri, servis entegrasyonu)
4. `61aaeb6 feat(pro): add professional notification inbox` (Görev 6, 7: Pro gelen kutusu ekranı, Pro push istemcisi, route entegrasyonu)
5. `55a83f6 feat(pro): route professional push deep links` (Görev 8, 9: Deep-link router matrisi ve Hesap ekranı bildirim ayarları)
6. `b7ea534 ci(pro): add isolated mobile release pipelines` (Görev 10: Android AAB/APK ve iOS unsigned/signed CI pipeline'ları)
7. `docs(pro): verify phase five distribution readiness` (Görev 11, 12, 13: Cihaz kabul matrisi ve bağımsız doğrulama raporu)

---

## 2. Veritabanı ve Şema Doğrulaması

- **Migration Dosyaları:** `20261028000000_push_app_target.sql` ve sonradan eklenen `20261028000100_push_app_target_hardening.sql`.
- **Tablo Değişikliği:** `push_subscriptions` tablosuna `app_target text NOT NULL DEFAULT 'social'` sütunu ve `CHECK (app_target IN ('social', 'pro'))` kısıtı eklenmiştir.
- **Performans İndeksi:** `CREATE INDEX IF NOT EXISTS idx_push_subscriptions_profile_target ON push_subscriptions (profile_id, app_target) WHERE is_active = true;`
- **RPC Güncellemesi:** `register_push_subscription` fonksiyonuna `p_app_target text DEFAULT 'social'` parametresi eklenmiş, geçersiz hedefler fail-closed olarak `social`'a düşürülmüştür.
- **Bildirim Dağıtım Tetikleyicisi (`notify_on_notification`):**
  - Bildirim türüne göre (`p_kind`) hedef uygulama (`social`, `pro` veya her ikisi) belirlenir.
  - İlgili kullanıcının yalnız ilgili `app_target` değerine sahip aktif cihazlarına bildirim kuyruklanır (`push_delivery_queue`).
  - Sosyal bildirimler Pro cihazlarına, operasyonel bildirimler ise son kullanıcı App cihazlarına asla iletilmez.
- **Düzeltme turu güvenliği:** `drop_push_subscription` artık kullanıcı + endpoint + `app_target` ile sınırlandırılmıştır. `my_pro_notifications` ve `mark_pro_notifications_read` RPC'leri Pro gelen kutusunun sosyal kayıtları okumamasını veya okundu işaretlememesini sağlar. Fonksiyon yürütme izinleri yalnız `authenticated` rolüne açıkça verilmiştir.

---

## 3. 42 Bildirim Türü İzolasyon Matrisi

SwanSport sistemindeki toplam **42 bildirim türü** (`notification_kinds`) 3 kategoride kesin kurallarla gruplanmıştır:

1. **Yalnızca Sosyal (9 Tür - Yalnız `social` hedefine gider):**
   - `message`, `follow`, `mention`, `post_repost`, `post_quote`, `partner_request`, `partner_request_accepted`, `offer`, `achievement`.
2. **Yalnızca Pro (15 Tür - Yalnız `pro` hedefine gider):**
   - `referee_assignment`, `expense_approval`, `expense_rejected`, `commitment_due`, `account_negative`, `bank_unmatched`, `period_closed`, `period_blocked`, `turf_slot_request`, `turf_field`, `turf_manager`, `court_waitlist`, `turf_delegation`, `store_decision`, `moderation`.
3. **Her İkisi (18 Tür - Hem `social` hem `pro` hedefine gider):**
   - `match_live`, `match_result`, `fee`, `fee_reminder`, `payment`, `donation`, `attendance`, `attendance_reminder`, `event`, `announcement`, `document`, `documents`, `document_expiry`, `support`, `eligibility`, `training_session`, `training_result`, `application`.
4. **Bilinmeyen Türler:**
   - Güvenli varsayılan olarak fail-closed mantığıyla yalnızca `social` hedefine atanır, Pro operasyonlarına sızamaz.

---

## 4. Cloudflare Pages Push Servisi ve FCM Yapılandırması

- **Dosya:** `functions/api/push.js`
- **FCM Servis Hesabı İzolasyonu:**
  - `social` gönderimleri için `env.FCM_SERVICE_ACCOUNT` kullanılır.
  - `pro` gönderimleri yalnız `env.PRO_FCM_SERVICE_ACCOUNT` kullanır; sosyal servis hesabına geri düşmez.
- **Android Bildirim Kanalı Ayrımı:**
  - Pro bildirimleri için `swansport_pro_default` kanalı konfigüre edilmiştir.
  - Social bildirimleri için `swansport_default` kanalı korunmuştur.
- **Doğrulama Güvenliği:**
  - `appTarget` parametresi doğrulanır; geçersiz hedef değerleri HTTP 400 ile anında reddedilir.
  - APNs alert, sound, category ve priority alanları platform standartlarına tam uyumludur.

---

## 5. Veri Katmanı ve Modeller

- **Paket:** `packages/swansport_data`
- **Yeni Model:** `PushAppTarget` enum (`PushAppTarget.social`, `PushAppTarget.pro`) ve `fromWire` / `wireName` yardımcıları (`packages/swansport_data/lib/src/push_target.dart`).
- **Envanter ve Validator:** `proNotificationKinds` (33 tür: 15 pro-only + 18 both) ve `isProNotificationKind(kind)` fonksiyonu.
- **Servis Güncellemesi:**
  - `PushSubscriptionService.registerSubscription` metoduna `appTarget` parametresi eklenmiş, varsayılan olarak `PushAppTarget.social` tanımlanmıştır.
  - `proNotificationsProvider`, genel ilk 50 satırı istemcide filtrelemek yerine `my_pro_notifications` RPC'sini kullanır. Pro okundu işlemleri de ayrı `mark_pro_notifications_read` RPC'sine gider.
  - Ortak enum `PushSubscriptionState` olarak adlandırılmış; sosyal uygulamadaki yerel `PushSubState` ile derleme çakışması kaldırılmıştır.

---

## 6. Pro İstemcisi ve Bağımlılıklar

- **Uygulama:** `apps/swansport_pro` (Sürüm: `0.1.4+6`)
- **Bağımlılıklar:** `firebase_core: ^4.14.0` ve `firebase_messaging: ^16.6.0` `pubspec.yaml` dosyasına eklenmiştir.
- **Sözleşme Koruması:** `tools/pro_app_contract_test.py` güncellenmiş; firebase paketlerine izin verilirken, izole olmayan paketlerin (`swansport_branch_engine`) yasaklı kalması ve repoda hiçbir firebase JSON/plist sırrının bulunmaması kuralı güvenceye alınmıştır.
- **Pro Push İstemcisi:** `apps/swansport_pro/lib/app/push/pro_push_client.dart`
  - Web ve konfigürasyonsuz ortamlarda (`kIsWeb` veya eksik Firebase Options) çökmeden sessizce fallback yapar.
  - Mobil açılışta `swansport_pro_default` kanalını başlatır ve token aldığında `PushAppTarget.pro` olarak Supabase'e kaydeder.
  - Oturum açıldığında abone olur. Çıkışta Pro aboneliği oturum sona ermeden önce silinir, yerel FCM token'ı iptal edilir ve ardından Supabase oturumu kapatılır.
  - `FirebaseMessaging.onMessage`, `onMessageOpenedApp` ve `getInitialMessage` akışları `ProPushCoordinator` üzerinden görünür uyarı ve güvenli yönlendirmeye bağlanmıştır.

---

## 7. Pro Gelen Kutusu (`SharedProInboxScreen`)

- **Paket ve Dosya:** `packages/swansport_pro_features/lib/src/inbox/shared_pro_inbox_screen.dart`
- **Tasarım ve Özellikler:**
  - SwanSport koyu tema (`#0F172A`, `#1E293B`, `#38BDF8`) tasarım jetonlarına tam uyum.
  - Sekme ayrımı: "Tümü" ve "Okunmamış" filtre çipleri.
  - Toplu işlem: "Tümünü Okundu İşaretle" butonu.
  - Yenileme: `RefreshIndicator` ile pull-to-refresh desteği.
  - Boş durum ve hata durumu: Ağ hatasında nazik hata mesajı ve "Yeniden Dene" butonu.
  - Responsive Güvencesi: 320px genişlikte render flex taşması oluşmaması için çip satırı `SingleChildScrollView` ile sarılmıştır.
  - Semantik Erişilebilirlik: Ekran okuyucular için `Semantics` etiketleri ve minimum 44x44 dokunma hedefleri tanımlanmıştır.

---

## 8. Deep-Link Yönlendirme Matrisi ve Güvenli Fallback

- **Dosya:** `apps/swansport_pro/lib/app/push/pro_notification_route_handler.dart`
- **Operasyonel Rota Eşleşmeleri:** Gerçek GoRouter yolları kullanılır: `/operasyon/hakem-gorevleri`, `/operasyon/yoklama`, `/operasyon/antrenmanlar`, `/operasyon/muhasebe`, `/operasyon/tesis-gorevleri`, `/operasyon/federasyon-maclar`, `/operasyon/platform` ve geçerli maç UUID'si için `/operasyon/hakem-canli/:id`.
- **Güvenli Fallback:**
  - Dış URL, query/fragment, geçersiz UUID veya tanınmayan rota reddedilir ve `/gelen-kutusu` yoluna düşer. Hedef ekran kendi `ProOperationsGate` / `SwanAccess` kontrolünü ayrıca uygular.

---

## 9. Hesap Ekranı Profesyonel Bildirim Ayarları

- **Dosya:** `apps/swansport_pro/lib/features/account/pro_account_screen.dart`
- **Kategori Tercihleri:**
  - Kulüp ve İdari Bildirimler (`kulup`)
  - Müsabaka ve Görev Bildirimleri (`musabaka`)
  - Finans ve Aidat Bildirimleri (`aidat`)
  - Antrenman ve Yoklama Bildirimleri (`antrenman`)
- **Cihaz Durumu:** Cihaz bildirim izin durumu ve sistem bildirim ayarlarına yönlendiren bilgi kartı entegre edilmiştir.
- **Flutter 3.47 Uyumluluğu:** `SwitchListTile.adaptive` bileşenleri `Material(type: MaterialType.transparency)` ile sarılarak tema arka plan uyarıları ve assertion hataları önlenmiştir; `activeTrackColor` özelliği kullanılmıştır.

---

## 10. CI/CD ve Dağıtım Pipeline’ları

- **GitHub Actions Workflows:** `.github/workflows/build_pro_production_preview.yml` (imzasız/debug-imzalı indirilebilir önizleme) ve yalnız elle çalışan `.github/workflows/build_pro_signed_mobile.yml` (gerçek imzalı mobil artefaktlar).
- **Android Dağıtımı:**
  - Önizleme akışı debug imzalı APK üretir; bunu mağaza artefaktı olarak sunmaz.
  - Manuel imzalı akış Pro'ya özel Firebase JSON ve keystore girdilerini zorunlu tutar, paket/proje kimliğini doğrular ve imzalı APK + AAB üretir.
  - Paket sağlığı ve güvenliği için SHA-256 doğrulama özeti (`checksums.txt`) oluşturulur ve release artifact olarak saklanır.
- **iOS Dağıtımı:**
  - Önizleme akışı Firebase kapalı, imzasız IPA üretir ve yer tutucu plist'i paketten çıkarır.
  - Manuel imzalı akış Pro Firebase plist'i, Pro Apple sertifikası/provisioning profile ve `aps-environment=production` yetkisini zorunlu tutarak IPA üretir. Otomatik mağaza/TestFlight yüklemesi yapmaz.
- **Web Dağıtımı:**
  - Komut: `flutter build web --release --no-pub -t lib/main_production.dart --dart-define=APP_ENV=production`
  - Derleme süresi: 75.0 saniye.
  - Çıktı: `apps/swansport_pro/build/web` dizini eksiksiz üretilmiştir.

---

## 11. Cihaz Kabul Matrisi Özeti

- **Doküman:** `docs/swansport-pro-device-acceptance-matrix.md`
- **Senaryo Sayısı:** 19 senaryo tanımlanmıştır.
- **Şeffaf Durum Bildirimi:**
  - Canlı fiziksel donanım testi gerektiren senaryolar (SC-01 .. SC-03, SC-05 .. SC-08, SC-16): **BEKLİYOR (Fiziksel Cihaz Testi Gerekli)**
  - Otomatik testlerle kanıtlanan mimari/arayüz senaryoları (SC-04, SC-09 .. SC-15, SC-17 .. SC-19): **OTOMATİZE KANITLANDI (Fiziksel Cihaz Bekliyor)**
  - Hiçbir fiziksel cihaz testi manipüle edilmemiş veya hileli olarak PASS gösterilmemiştir.

---

## 12. Test ve Statik Analiz Kanıtları

Tüm testler ve statik analiz kontrolleri başarıyla tamamlanmıştır:

```text
1. Faz 5 SQL Testleri:
   Command: node --test tools/push_target_sql_test.mjs
   Result: 8/8 PASS.
   Command: npm ci --prefix tools --ignore-scripts --no-audit --no-fund && npm test --prefix tools
   Result: 335/335 PASS, 0 fail, 0 skipped.

2. Python Sözleşme ve Doğrulama Testleri:
   Command: python -m unittest discover -s tools -p "*_test.py"
   Result: 41/41 PASS.
   Command: python tools/check_migrations.py -> 143 migration, sorunlu dosya: 0 (OK)
   Command: python tools/check_push_routes.py -> 42 esleme, kayip esleme yok (OK)
   Command: python tools/check_faq.py -> bayrak: 53, SSS: 53, hepsi eslesiyor (OK)

3. SwanSport Pro Uygulama Testleri:
   Command: cd apps/swansport_pro && flutter test --no-pub
   Result: 69/69 tests passed (All tests passed!).

4. SwanSport Pro Özellik Paketi Testleri:
   Command: cd packages/swansport_pro_features && flutter test --no-pub
   Result: 141/141 tests passed (All tests passed!).

5. Veri Katmanı Testleri:
   Command: cd packages/swansport_data && flutter test --no-pub
   Result: 519/519 tests passed (All tests passed!).

6. SwanSport sosyal uygulama regresyonu:
   Command: cd apps/swansport_app && flutter test --no-pub
   Result: 630/630 tests passed; önceki `PushSubState` derleme çakışması kapandı.

7. Statik Kod Analizi:
   - apps/swansport_pro: flutter analyze -> No issues found!
   - packages/swansport_pro_features: flutter analyze -> No issues found!
   - packages/swansport_data: flutter analyze -> 0 error, 0 fatal issues.
   - packages/swansport_data: 0 error/uyarı; depoda önceden bulunan info seviyesinde lintler raporlandı.
   - Değişen Dart dosyaları `dart format` ile biçimlendirildi.
```

---

## 13. Regresyon ve Güvenlik Güvencesi

1. **Sosyal Akış ve Ana Sayfa Bütünlüğü:** SwanSport mobil ve masaüstü uygulamasının Ana Sayfa akışı, sosyal gönderileri ve keşif bileşenleri tamamen korunmuş, hiçbir dosyasında yetkisiz değişiklik yapılmamıştır.
2. **Sırların Korunması (Zero Secret Leakage):** Repoya hiçbir `google-services.json`, `GoogleService-Info.plist`, `.env`, keystore veya özel anahtar dosyası yazılmamış; git değişiklikleri denetlenmiştir.
3. **Üretim ve Staging Veritabanı İzolasyonu:** Canlı veritabanına bağlanılmamış; `supabase link` veya `db push` çalıştırılmamıştır. Yalnızca migration dosyası ve lokal mock testleri hazırlanmıştır.
4. **Veri ve Yetkilendirme Sınırları:** Widget seviyesinde doğrudan PostgREST veya Supabase çağrısı yapılmamış; tüm işlemler `SwanAccess` ve `packages/swansport_data` sağlayıcıları üzerinden yürütülmüştür.

---

## 14. Codex Supervising Ajanı İnceleme Notları ve Hazırlık Durumu

Bağımsız Codex incelemesinde bulunan veri izolasyonu, logout sırası, native push yaşam döngüsü, mobil imzalama ve raporlama eksikleri kaynak kodda kapatılmıştır. Canlı migration uygulanmamış, uzak workflow tetiklenmemiş ve fiziksel cihaz UAT yapılmamıştır. Bu nedenle “mağazaya hazır” kararı ancak manuel imzalı workflow başarıyla gerçek artefakt ürettikten ve kabul matrisi fiziksel cihazlarda tamamlandıktan sonra verilebilir.
