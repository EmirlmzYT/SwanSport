# Faz 3 — Mobil Hakem Kokpiti doğrulaması

2026-10-13. Kullanıcı 0112 sunucu motorunu açıkça onayladı. Bu iş yereldir;
canlı migration, APK/web yayını, commit veya push yapılmadı.

## Sunucu sözleşmesi

- `0112_referee_cockpit_engine.sql` ilk satırında 15s lock timeout vardır.
  Önce 0110/0111 ve onların önceki migration bağımlılıkları gerekir.
- Aday sorgusu `referee_lineup_candidates`: yalnız kabul edilmiş aktif,
  aynı branş başhakem/masa görevlisi; UUID, taraf, forma/lisans/vize, genel
  uygunluk ve seçim durumu. Çocuk/bilinmeyen doğumda canlı veli tercihi
  kontrol edilir, ret baskındır; izin yoksa ad NULL. TC, telefon, teşhis veya
  sağlık notu dönmez. Onay yazıcısı ayrıca mevcut C1/club/team/license/health
  ve maç notu kontrolünü tekrar yapar. UI seçilen ama sonradan uygunluğu veya
  yayımlanmış kadrosu değişen sporcuyu sessizce diziden çıkarmaz.
- `match_live_events` append-only günlüktür. RPC, maç kilidi ve iyimser
  sürümle tek sıra numarası üretir. Aynı operation ID ve payload tekrarı
  aynı sonucu verir; farklı payload reddedilir. Skor istemciden alınmaz;
  olaylar yeniden yürütülür. Undo son geçerli olayı silmez, yeni ters olay
  kaydeder. Kart/değişiklik doğru tarafın aktif/yedek snapshot'ına bağlanır.
  Süre ve olay dakikası sunucunun clock start/pause zamanlarından hesaplanır.
- Rapor `referee_submit_match_report`: iki tarafın kilitli esamesi, kabul
  edilmiş aktif doğru görev ve açık maç gerekir. İmzalı rapor, mevcut
  `org_result_revisions`, played durumu, resmi CV, veli bildirimi ve audit
  aynı transaction'da yazılır. Rapor notu özeldir, genel sonuç protokolüne
  gömülmez. Aynı rapor operation ID'si idempotenttir. Sonradan değiştirme/
  silme yok; hakem ikinci sonuç revizyonu yazamaz.
- Genel `_federation_require` değiştirilmedi. Özel, client ACL'si kapalı
  `_referee_write_context` satırı yalnız rapor RPC'sinin transaction/actor/
  match/revision kombinasyonuna yetenek verir. Guard ve CV yardımcıları bu
  dar bağlamı tanır; diğer maç/kurum/lisans/sonuç yazıları eski yetkiyi ister.
  Caller tarafından forge edilebilen session GUC'si yok; bağlam satırı iş
  sonunda silinir, hata halinde transaction ile geri alınır.
- Esameye alınmayan sporcuya yanlış CV/bildirim üretilmez. Dar helper,
  hakem raporu olan maçlarda ilk ve sonraki federasyon revizyonlarının
  CV/veli okumasını maç esamesine bağlar. Turnuva kadro revizyonuna maç
  esamesi yazılmaz. Audit hatası olay/tescili atomik geri alır.
- Kaynak tabloların RLS/ACL'si açılmadı. Yeni günlük, rapor ve capability
  tablolarında client doğrudan okuma/yazma yok. Yeni public/anon kadro yolu
  yok. Profil silmede yalnız actor FK NULL olabilir; sporting geçmiş kalır.

## Mobil entegrasyon

- Gerçek rota tablosu `app/swansport_app.dart`; nested UUID rotaları yeni
  `app/router.dart` yardımcı fabrikasındadır. `AccountRouteGate` korunur.
  Dört ekran da SwanAccess.isReferee + referee_cockpit kapısını uygular;
  hangi maçın yönetilebildiğinin son kararını sunucu verir.
- Profil dosyası gerçekte `features/social/presentation/profile_screen.dart`:
  kişisel profil, aktif hakem ve açık bayrak için giriş. Feed gerçek bugünkü
  kabul edilmiş başhakem/masa maçını gösterir; tek desteklenen maçta esameye
  gider. İdari TodayTasks veya sahte hikâyeler geri eklenmedi.
- Beşli SwanBottomNav değişmedi. İkincil sayfalar mevcut swanModuleAppBar,
  SwanType (gerçek h1/h2/h3/body/bodySm/caption adları), SwanPalette,
  SwanSpace ve SwanRadius kullanır. Brief'teki SwanShape/titleMedium isimleri
  için ikinci token sistemi yazılmadı. Saha eylemleri token'dan 48dp minimum
  ve yüksek kontrastlı accentFill/onAccent kullanır; haptic vardır.
- Atamalar ve bugünkü kart, ortak 30s aktif liste yenileyicisini kullanır.
  Canlı durum 5s yenilenir; timer'lar provider disposal'da kapanır. UI
  kronometre ticker'ı kaplı rotada çizim yapmaz ve dispose'da kapanır.
- Yazma sırasında çift gönderim engellenir. Belirsiz cevapta aynı UUID,
  sürüm ve payload saklanır; yeni olay gönderilmez. Sonraki permission
  denial önceki commit'in olmadığının kanıtı sayılmaz. Hesap değişiminde
  controller ayrılır, geç cevap başka ekrana başarı mesajı taşımaz.
  Oyuncu/mazeret dialogları açan hesabı izler; hesap değiştiğinde özel içerik
  çizilmez ve açık popup kapanır.
- Görev sekmesi gerçek `match_status` kullanır, accepted atamayı oynanmış
  maç saymaz. `my_referee_matches(text)` yeni dönüş kolonları için eski
  imza DROP edilip tek imzayla kuruldu; ret notu yalnız kendi görevinde.
- Gerçek atama tetikleyicisi referee_assignment bildirimi üretir. Push ve
  bildirim listesi `/hakem/gorevler` kapılı girişine gider. Bayrak admins,
  SSS aktif ve aynı anahtara bağlıdır; eski 40 push eşlemesi korunur.

## Kapsam ve sınırlamalar

Canlı sonuç tescili **futbol, basketbol ve tenis** için uygulanmıştır.
Futbol/basketbol sayı toplamı, tenis oyun ve tamamlanmış set toplamı
kullanır. Yüzme/atletizm/okçuluk bireysel derece protokollerini iki takım
skoruna çevirmek yanlış olacağından bu yollar açıkça kapalıdır. Genel
kart/faul kaydı vardır; federasyonun tüm branş bazlı disiplin/otomatik ceza,
uzatma, tie-break puan sayacı veya müsabaka bitiş kuralı motoru değildir.
Teniste tamamlanmış set doğrulanır; diğer sporlarda final kararını görevli
verir. Oturumla yapılan tescil nitelikli elektronik imza iddiası taşımaz.

Bu **çevrimiçi** bir kokpittir. Başarıyla kaydedilmiş olaylar sunucuda
kalıcıdır. İmzalanmamış esame seçimleri, rapor metni ve belirsiz isteğin
retry taslağı RAM'dedir; uygulama zorla kapatılırsa kaybolabilir. Cihaz
kapandıktan sonra sunucu zaman çizelgesini kontrol etmeden aynı eylemi
yeniden girme. Çevrimdışı günlüğe/power-loss garantisine dair iddia yoktur.

## Doğrulama

- `node --test tools/referee_cockpit_sql_test.mjs`: **63/63 geçti**
  (55 önceki + 8 yeni gerçek PostgreSQL/PGlite fixture senaryosu).
  Kapsam: ACL/rol/branş/kabul, çocuk maskesi, aday durumları, esame kilidi,
  tekrar/sürüm/undo/değişiklik, atomik audit, rapor/CV/veli snapshot,
  eski federasyon yazımı, gerçek atama push payload'ı, replay/immutable.
- `node tools/platform_mission_control_sql_test.mjs`: **5/5 geçti**.
- `python tools/check_faq.py`: **40/40**.
- `python tools/check_push_routes.py`: **41**, kayıp yok.
- `python tools/check_migrations.py`: **112**, parse hatası yok.
- `python tools/check_mobile_ui_tokens.py --syntax`: **16/16** token
  kaynağı, **551** Dart dosyasında sözdizimi hatası yok.
- Navigation testinin kaynak sözleşmesi ayrıca statik kontrol edildi:
  **42** named rota/girişinde eksik yok. Nested rota testi eklendi.
- **18 yeni Dart/widget testi + 1 navigation senaryosu hazır**;
  operation UUID/retry/conflict/disposal, maskeli DTO, süre/değişmezlik,
  gate/entry/history/blocked lineup, UUID deep links ve 48dp hedef testleri.
- `git diff --check` / staged diff-check temiz.

**Flutter/Dart SDK yok:** veri/app `flutter test` ve `flutter analyze`
komutları çalıştırılmaya çalışıldı, executable bulunamadı. Yukarıdaki
Dart testleri **çalıştırıldı sayılmaz**, tree-sitter tip denetimi değildir.
Format/analyze/build, gerçek widget/navigation/feature sync regresyonu,
telefon ekranı/güneş/tek-el görsel QA, cihaz haptic, gerçek PostgREST ve
iki eşzamanlı oturum UAT hâlâ açık. Yayın öncesi SDK bulunan ortamda:

```powershell
# packages/swansport_data
flutter test
flutter analyze
# apps/swansport_app
flutter test
flutter analyze
```

Bayrak testers/everyone yapılmadı; canlı migration/deploy yapılmadı.
