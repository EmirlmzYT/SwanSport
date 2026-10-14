# 0118 Maç/Kulüp Bildirimleri & iOS Push — yerel doğrulama

2026-10-14. Kaynak entegrasyonu yerelde hazır; canlı SQL, deploy, sürüm,
commit/push, Apple/Firebase hesabı değişikliği veya gerçek cihaza gönderim yok.

## iOS teşhisi ve hazırlık

- Dart'taki Android-only destek gerçek blokajdı; iOS artık aynı FCM arayüzünü
  kullanır. Alert/badge/sound izni istenir; izin reddi ayrı sonuçtur. APNs token
  boşken FCM getToken çağrılmaz: en fazla on sorgu/250ms aralık, ardından açık
  `apnsUnavailable` hatası. Firebase initialization eşzamanlı çağrılarda tek
  Future ile paylaşılır, başarısızlık sonraki çağrıda yeniden denenebilir.
- Token-refresh akışı initialization sonrası bağlanır; root observer subscription
  sahibi/dispose eder. Bildirim akışı ve ilk mesaj hataları yakalanır. Native
  foreground sistem banner/sound kapalı, mevcut uygulama snackbar'ı korunur;
  iki ayrı foreground uyarısı üretilmez. Cihaz izin kontrolü sessiz yenilemede
  izin istemez; yalnız açık cihaz anahtarı izin isteme yolunu kullanır.
- Info.plist background fetch + remote-notification içerir. Xcode Push ve
  BackgroundModes capability işaretleri, CODE_SIGN_ENTITLEMENTS ve Firebase
  plist resource bağlandı. Entitlement Debug development, Release/Profile
  production seçer; tek hardcoded production dosyasıyla debug imzası bozulmaz.
- CI `GOOGLESERVICE_INFO_PLIST_BASE64` değerini `configure_ios_firebase.py`
  ile doğrular: plist biçimi, com.swansport.app bundle, swanspor Firebase projesi
  ve gerekli config alanları. Eksik/yanlış config **derlemeyi açıkça durdurur**;
  sahte plist üretilmez. Bu, unsigned CI derlemesi için de geçerlidir. Dosya
  gitignore'da, config/anahtar değerleri loglanmaz; bu görev gerçek secret okumadı
  veya yaratmadı. CI yapılandırma sözleşmesi testini de çalıştırır.
- FCM `notification` alanı zaten vardı; bunun APNs `alert` eşlemesi bulunabilir.
  Explicit APNs bloğunun yokluğu tek başına tüm iOS bildirimlerinin çalışmama
  kanıtı değildir. Yeni blok alert/sound/default/badge=1 ve APNs alert headers
  sağlar; Android channel/data URL korunur. Badge 1 durum işaretidir, gerçek
  unread sayacı veya app-open badge sıfırlama motoru değildir.
- Native FCM için gereksiz web VAPID zorunluluğu kaldırıldı. Web VAPID hatası
  ilgili abonelikte açık kalır; PUSH_SECRET doğrulaması korunur. Canlı maç
  bildiriminde Android/APNs/web TTL 60s; eski skor günler sonra gösterilmesin.
  Diğer bildirimlerin mevcut TTL davranışı değiştirilmez.
- Bunlar imza/yetki yerine geçmez. Uygun APNs provisioning/App ID capability,
  doğru Firebase iOS uygulaması ve Firebase'e yüklenmiş APNs authentication key
  gerekir. Unsigned/ücretsiz Personal Team yeniden imzası bu yetkileri otomatik
  kazanmaz. TestFlight tek yol değildir; APNs destekli geçerli geliştirme veya
  dağıtım profili de önemlidir. Üyelik ücreti bu görevde araştırılmadı/ödenmedi.
  [Firebase Flutter iOS gereksinimleri](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
  [Apple capability rehberi](https://help.apple.com/xcode/mac/current/en.lproj/dev88ff319e7.html).
- Background modes arka plan işleme hazırlığıdır; kullanıcıya görünen her
  alert için tek başına yeterli veya teslim garantisi değildir. OS izinleri,
  imza, ağ, APNs/FCM config ve fiziksel cihaz ayrıca doğrulanmalıdır.

## 0118 güvenlik ve bildirim üretimi

- Planın nonexistent `official_matches` yerine gerçek `org_matches` FK'sı;
  clock_start/score/period_end/undo ve result_version kullanılır. İkinci maç veya
  skor motoru kurulmaz. Kaynak journal/kadro/athletes RLS/ACL açılmaz.
- `match_followers` yalnız kendi profiline RLS'li; yazı ayrıca public/official
  maç ve kullanıcıya açık bayrak ister. Anon takip/RPC'leri kapalıdır; UUID
  gizlilik kapısı değil. Başka profilin takip durumu okunamaz/değiştirilemez.
- `get_match_follow_status` effective maç/kulüp tercihlerini projekte eder.
  `toggle_match_follow` atomik kilitlidir. UI ekstra `set_match_follow(uuid,bool)`
  idempotent desired-state RPC'sini kullanır: belirsiz yanıtı yeniden denemek
  ikinci kez toggle edip tercihi tersine çevirmez. Off, eski kendi kaydını
  özellik/yayın geri alındıktan sonra da sessize alabilir.
- Mevcut follows hedefleri yalnız club/profile'dır; hayali team tipi eklenmedi.
  Resmi katılımcının club_id'si üzerinden kulüp takipçileri ilgili takımın maçına
  dahil edilir. Maç+iki kulüp bir kişiyi yalnız bir kez seçer. `muted` override
  kulüp takibinden gelen uyarıyı da kapatır; yalnız satır silmek bunu başaramazdı.
  Tür tercihleri booleans ile korunur; UI'da ayrı kickoff/score/final düzenleyicisi
  henüz yoktur, aç/kapa üç tercihi birlikte ayarlar.
- Recipient hem live_match_notifications hem live_match_hub bayrağını
  karşılamalıdır. Bildirim admins başlar, seed mevcut yayın tercihini değiştirmez.
  Bayraklar yalnız ekranda değil üretim, takip yazma ve bildirim okumada da
  kontrol edilir. Sosyal kategorisi kapalıysa uygulama içi kayıt kalır fakat
  mevcut push_allowed telefon kuyruğunu kapatır; quiet tercih atlanmaz.
- İlk clock_start başlangıç uyarısıdır; pause/resume tekrar kickoff üretmez.
  Skor/periyot/set ve skor/set undo düzeltmesi bildirilir. Final ve sonraki
  resmi düzeltme güncel revizyon skorunu kullanır, rapor tekrarında çoğalmaz.
- Özel `match_notification_deliveries` ledger alıcı/maç/source tekilliğini
  notification silinse bile korur; anon/auth/PUBLIC erişimi yoktur. Olay,
  notification ve teslim anahtarı aynı transaction'dadır; kayıt hatası atomik
  geri alır. Operation retry aynı olayı tekrar insert etmez.
- Kilit ekranı metni yalnız yayımlanmış yasal kulüp isimleri ve public sayısal
  skor/set/oyun taşır. Oyuncu/çocuk/hakem adı, veli telefonu, TCKN, medical veya
  report/decline/disiplin notu **hiç seçilmez**. Consent değişse bile eski push'ta
  kişisel ad snapshot'ı yoktur. Actor null, sadece public maç UUID'si rota olur.
- `match_live` rezervasyonu fake insert/update'ı engeller. Bildirim raw SELECT/
  unread sayımı ve my_notifications yayını/bayrağı tekrar kontrol eder; yayın
  geri alınınca yeni okumalar ve üretim kapanır. Mark-read ve kendi bildirimi
  silme korunur; match_result veli kapsamı bozulmaz. Daha önce okunmuş/cihaza
  iletilmiş bildirim geri çağrılamaz; RLS kullanıcı hafızasını/screenshot'ı silmez.
- push_route 41 eski tür + match_live, UUID doğrulamalı `/canli-mac/<id>`.
  push_on_notification yeni türde entity_id gönderir; eski entity_type argümanı
  yüzünden `/canli-mac/match` üretmez. Özel veli sonucu notification ID rotası
  korunur. Bildirim listesi ve push-open mevcut public UUID router'a bağlanır.

## Mobil veri ve UI

- Immutable MatchFollowState ve saf Supabase servis; üç açık tipli provider.
  Durum auth/session + feature bağımlı, 30s polling, geç cevap/dispose timer
  korumalıdır. Fixture/misafir backend yazmaz. Tek tek görünür kart durum
  sorguları batch değildir; çok maçta sorgu/pil maliyeti ayrıca ölçülmelidir.
- Detayda token uyumlu aç/kapat, busy/error, başarılı kayıt haptic ve hesap
  değişimi/late-reply koruması. Belirsiz desired-state retry RAM'dedir; uygulama
  kapanırsa yeni GET gerçek durumu alır. Kart zili gerçek server durumudur.
- Maç tercihi **cihaz izni veya başarılı fiziksel teslim kanıtı değildir**.
  UI bunu açıkça belirtir ve mevcut Bildirimler cihaz anahtarına bağlar; guest
  merkezi SwanAccess.matchFollow hesap kapısından geçer. Telefon/TCKN yetkisi
  salt public maç izleme/takip için uydurulmaz. Beş alt sekme değişmez.
- Genel native cihaz kapatma/yeniden başlatma ve auto-init/token yenileme
  senaryoları gerçek cihazda ayrıca denenmelidir; bu teslim kalıcı native
  device opt-out deposu veya yeni notification preference sistemi kurmadı.

## Testler ve açık kabul sınırları

- SQL son tam regresyon: **80/80** (73 mevcut + 7 yeni 0118). RLS/anon/private,
  replay, idempotent set/toggle, club mute, event retry/undo, set/final/correction,
  raw/RPC read marking/withdrawal, dedup/delete, rollback, global category ve
  recipient rollout kapıları; gerçek queue URL ve 41 eski rota doğrulanır.
- Node gönderici **5/5**: APNs/Android payload + TTL, gerçek handler/OAuth
  serializasyonu (mock fetch), secret/config/error/defaultler. Python iOS
  sözleşmesi **3/3**: plist/entitlements/Xcode + sentetik Firebase config + CI sıra.
- Migration **118 parse, 0 sorun**; SSS **44/44**; push **42 kayıpsız**;
  mobil token **23/23**, Dart syntax **587, 0 hata**; diff kontrolleri temiz.
- Üç yeni Dart test dosyasında **13 senaryo** (5 veri/provider, 5 widget,
  3 native destek/APNs gate). Data/app test, analyze ve Melos format denendi;
  Flutter/Dart/Melos yokluğundan **çalışmadı**. Syntax typecheck/build/widget
  veya fiziksel iPhone/APNs kabulü değildir.
- macOS/Xcode build, signed entitlement/provision profile/Google plist bundle
  inspection, TestFlight, APNs key/bundle/project eşleşmesi, foreground/
  background/terminated tap, izin ret/iptal, iki gerçek oturum yarışı ve yük/pil
  testi açık. CI sadece hazırlandı, çalıştırılmadı; gerçek secret konulmadı.
- PGlite tek bağlantı ve reduced fixture; 0113–0115 dahil tam production şeması,
  gerçek PostgREST/net/FCM/APNs yolu ayrı UAT ister. Ledger retention, throttle,
  batch/outbox worker ve physical delivery retry/receipt yoktur. Mevcut
  push_on_notification HTTP hatasını yutabilir; FCM başarısı cihazın bildirimi
  gösterdiği anlamına gelmez. DB tekilliği exactly-once fiziksel teslim garantisi
  değildir. Voleybol canlı motoru ayrıca eklenmedi; 0112 branş sınırı sürer.
- Yalnız görev değişiklikleri stage; önceki 0116/0117 ve üç kullanıcı planı
  korunur. Rapor, production-ready veya iPhone'da çalıştı iddiası değildir.
