# Federasyon Yayın Merkezi — Yerel Doğrulama ve Güvenlik Raporu

2026-10-19. 0126–0131 migration zinciri, ortak veri katmanı servis ve sağlayıcıları,
Flutter mobil arayüzü ve testleri yerelde tamamlandı ve doğrulandı.
Canlı Supabase projesine uygulanmadı; üretim deploy'u yapılmadı.

---

## 1. Kapsam ve Ürün Hedefi

Federasyonun resmi takvim, fikstür, canlı skor, tescilli sonuçlar, lig puan durumu,
disiplin kararları, müsabaka erteleme/iptal duyuruları ve takip/bildirim süreçleri
tek ve bütüncül bir ürün akışında (`/federasyon`) birleştirildi.
Mevcut hakem kokpiti (0112), resmi sonuç (0103), canlı seyirci hub'ı (0116),
lig tablosu motoru (0117) ve maç takip altyapısı (0118) baştan yazılmadı;
tamamen bu altyapıların üzerine inşa edildi.

---

## 2. Mimari ve Güvenlik Sınırları

### 2.1. Migration Zinciri
- **0126 (`0126_federation_result_revisions_stream.sql`):** Kamusal maç detayına sonuç sürümü (`result_version`) ve revizyon geçmişini yansıtacak RPC projeksiyonunu kurdu.
- **0127 (`0127_public_result_reason_redaction.sql`):** Operatörün serbestçe yazdığı revizyon gerekçesini (`r.reason`) kamusal RPC'den çıkardı; yerine güvenli sabit etiketler (`public._public_result_revision_label`) getirdi ("Resmi sonuç tescil edildi" / "Resmi sonuç güncellendi").
- **0128 (`0128_federation_disciplinary_bulletin.sql`):** Resmi disiplin kararları ve duyurular için temel RPC'leri ve filtreleme altyapısını oluşturdu.
- **0129 (`0129_federation_bulletin_publication_contract.sql`):** Disiplin dosya gerekçesi (`disciplinary_decisions.reason`) ile kamusal bülten yayınını (`federation_disciplinary_bulletins.public_summary`) kesin olarak birbirinden ayırdı. Tablolara `_federation_bulletin_immutable()` değiştirilemezlik tetikleyicisi konuldu. Sporcu adlarında 18 yaş altı ve veli onayı olmayan sporcular `public.athlete_ref` ile maskelendi (`Sporcu (#A3F91C)`). `federation_bulletin` bayrağı eklendi.
- **0130 (`0130_federation_notice_notifications.sql`):** İptal ve erteleme duyurularının yayımlanması durumunda maçı ve kulüpleri takip eden kullanıcılara `trg_notify_federation_match_notice` ile bildirim gönderilmesi sağlandı. Kilit ekranı metinlerine çocuk/sporcu/hakem özel verisi sokulmadı.
- **0131 (`0131_public_match_header_result_revision_regression.sql`):** 0130'da güncellenen `_public_match_header` fonksiyonunun ertelenen/iptal edilen durumları kapsarken 0126/0127'den gelen `result_version` ve redakte `revision_reason` alanlarını koruması sağlandı.

### 2.2. Veri ve Rol İzolasyonu
- **Muhasebeci ve Üçüncü Şahıs Gizliliği:** Muhasebeciler sporcu kimliğini göremez (`acc_*` RPC'leri sporcu seçmez; `athlete_ref` maskesi kullanılır). Kamusal bülten ve duyuru tabloları RLS açık olup istemci rollerine doğrudan SELECT/INSERT/UPDATE'e kapalıdır.
- **Disiplin Kurulu Yetki Sınırı:** Yalnızca ilgili branş ve ilde yetkili Disiplin Kurulu üyesi `publish_disciplinary_bulletin` RPC'sini çağırabilir.
- **Duyuru Yetkisi:** Yalnızca Başkan veya İl Temsilcisi `publish_federation_match_notice` RPC'sini çağırabilir. Duyuru türü ile maç durumu (`cancelled`/`postponed`) uyuşmak zorundadır.
- **Değiştirilemezlik (Immutability):** Yayımlanan disiplin bülteni veya müsabaka duyurusu silinemez veya güncellenemez (`55000` hatası).
- **Bildirim Güvenliği:** Maç duyurusu bildirimleri (`match_live`), `match_notification_deliveries` tablosu üzerinde `notice:<notice_id>` anahtarıyla kaydedilir; mükerrer bildirim engellenir. Push gövdesi yalnızca kulüp isimleri ve güvenli durum bilgisini içerir.

---

## 3. Beş Noktadan Özellik Bayrağı Sözleşmesi (`federation_bulletin`)

`federation_bulletin` özelliği AGENTS.md değişmezlerine tam uyumlu olarak 5 noktada tanımlandı:
1. **SQL Migration Satırı:** `supabase/migrations/0129_federation_bulletin_publication_contract.sql` içinde `insert into public.feature_flags(key, audience, label) values('federation_bulletin', 'admins', 'Resmi Disiplin Bülteni')`.
2. **Dart Sabiti:** `packages/swansport_data/lib/src/feature_flags.dart` içinde `FeatureFlags.federationBulletin = 'federation_bulletin'`.
3. **Senkronizasyon Testi:** `packages/swansport_data/test/feature_flag_sync_test.dart` (4/4 geçti).
4. **SSS Kaydı (FAQ):** 0129 içinde `/federasyon` rotası ve `'Federasyon disiplin bülteni ve ceza kararlarını nereden görebilirim?'` sorusuyla eşleştirildi.
5. **Arayüz ve Veri Kapısı:** `FederationCenterScreen` içinde `ref.watch(featureEnabledProvider(FeatureFlags.federationBulletin))` ile sekmeyi gizler; `federation_center_service.dart` içinde bayrak kapalıyken bülten RPC'lerine istek atılmaz.

---

## 4. Branş Protokolleri ve Sonuç Tescil Akışı

Federasyon yetkilisi veya platform admini mobil üzerinden sonuç tescil ederken branşa duyarlı akış uygulanır:
- **Futbol & Basketbol:** Standart ev sahibi / deplasman sayısal skor girişi.
- **Tenis & Voleybol:** Dinamik set ekleme, set skorları doğrulama (`homeSets` vs `awaySets` hesaplaması) ve set listesi JSONB protokolü olarak gönderme.
- **Yüzme & Atletizm:** Bireysel derece, seri ve kulvar gerektiren branşlarda mobil tescil formu açılmaz; yetkili kullanıcıya açıkça masaüstü konsolu (`apps/swansport_console`) kullanması gerektiği bildirilir, sahte takım skoru üretilmez.
- **Yetki Kontrolü:** "Bekleyen Sonuçlar" butonu ve modalı yalnızca `SwanAccess.canPublishFederationResults` yetkisine sahip kullanıcılara görünür; yetkisiz federasyon üyelerine 42501 hatası ürettirilmez.

---

## 5. Takip ve Bildirim Bileşeni (`MatchFollowButton`)

- `MatchFollowButton` geriye dönük uyumlu `compact: true` parametresiyle genişletildi.
- "Bugün & Canlı" sekmesinde tam buton ve cihaz bildirim bilgilendirmesi sunulur.
- "Fikstür & Takvim" sekmesindeki yaklaşan müsabaka satırlarına kompakt takip butonu yerleştirildi.
- Her iki sekmede de takip butonları `FeatureFlags.liveMatchNotifications` bayrağı arkasında korunur.

---

## 6. Doğrulama ve Test Kanıtları

Yerel ortamda gerçekleştirilen doğrulama adımları:
1. `flutter test test/federation_center_test.dart`:
   - 23 testin tamamı geçti (**23/23 passed**).
   - Test edilen senaryolar: Header hero, sekme geçişleri, yönlendirme, boş/hata durumları, yetkili rozetleri, kapalı bayrak davranışları, 320px/375px dar ekran ve 1.6x metin ölçeği RenderFlex taşma denetimi, tescilli/revize sonuç rozetleri, Bekleyen Sonuçlar modalı, tenis dinamik set tescili, yüzme masaüstü konsol uyarısı, kamusal gerekçe redaksiyonu, disiplin bülteni ve maskelenmiş sporcu referansı (#A3F91C), alt filtreleme, bildirim bayrağı kapalı/açık takip butonu görünürlüğü, 0130 bildirim tetikleyicisi sözleşmesi ve 0131 regresyon sözleşmesi.
2. `flutter test test/match_following_test.dart test/live_match_test.dart test/navigation_test.dart`:
   - 23 testin tamamı geçti (**23/23 passed**).
3. `packages/swansport_data/test/feature_flag_sync_test.dart`:
   - 4 testin tamamı geçti (**4/4 passed**).
4. `python tools/check_migrations.py`:
   - 39 migration dosyasının tamamı kontrol edildi; **0 sorunlu dosya**.
5. `git diff --check`:
   - Temiz, biçimlendirme ve satır sonu hatası yok.

---

## 7. Üretim ve Canlı Dağıtım Sınırları

- **Canlı Veritabanı:** 0126, 0127, 0128, 0129, 0130 ve 0131 numaralı SQL migration'ları canlı Supabase veritabanına henüz uygulanmamıştır. Uygulanmadığı takdirde kamusal bülten ve duyuru sorguları güvenli biçimde boş liste döner; tescil RPC'si sunucu tarafında bulunamaz.
- **Fiziksel Push Bildirimi:** Gerçek iOS ve Android cihazlara push bildirimi teslimi için geçerli APNs p8 anahtarı, yetkilendirilmiş Apple App ID, Firebase Cloud Messaging konfigürasyonu ve Cloudflare worker (`https://swansport.pages.dev/api/push`) gizli anahtarı (`push_secret`) zorunludur.
- **Konsol Senkronizasyonu:** Bireysel branş tescilleri masaüstü web konsolu (`apps/swansport_console`) üzerinden yürütülmelidir.
