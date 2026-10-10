# Resmi federasyon sonucu ve sporcu CV — 2026-10-10

Yerel uygulama ve doğrulama tamamlandı. Canlı Supabase SQL, push ve Cloudflare deploy yapılmadı. Yeni arayüz 0103 uygulanmadan üretimde kullanılmamalıdır. Önceki migration'ların canlı durumuna dokunulmadı.

## Uygulanan akış

- Konsol > Federasyon > Resmi Sonuçlar (`/federasyon-sonuclari`). Mevcut modül kaydı, sidebar, yönlendirici koruması ve ana sayfa kısayolu kullanılır. Merkezi `SwanAccess.canWriteFederation(..., resultPublisher)` ve aktif görev bulunması gerekir; platform yöneticiliği/kulüp yöneticiliği tek başına açmaz.
- Sunucu yalnız görev kapsamındaki resmi, scheduled, sonuç sürümü sıfır maçları sayfalı döndürür. Form resmi kadro RPC'sinden sporcu seçtirir; isim gizliyse numaralı “Sporcu” etiketi kullanır. JSON/UUID yazma ekranı yoktur.
- Basketbol Q1–Q4, uzatmalar ve takım faulleri; futbol iki devre, eleme, uzatma, sıralı seri penaltılar ve isteğe bağlı gol/kart olayları; tenis 3/5 set formatı, oyunlar ve 7/10 hedefli tie-break; yüzme/atletizm kulvar-seri, derece, sıra ve DQ/DNF; okçuluk hedef-seri toplamları desteklenir.
- `validateMatchProtocol` saf Dart motorunda çalışır. Data katmanı derece metnini tamsayı milisaniyeye normalize eder. Eksik sayılar sıfır yapılmaz. Form sonuç sürümünü gönderir; çift gönderim engellenir. Belirsiz ağ yanıtında otomatik yeniden yazılmaz, sunucudaki sürüm kontrol edilir.
- İstenen `publish_official_match_result` 0096'da yoktu; var olan API `federation_publish_result` idi. 0103 eski imzayı korur, iki yolu tek özel `_federation_commit_result` yazıcısına bağlar. Eski kompakt API sözleşmesi korunur; yeni zengin protokol sunucuda ayrıca doğrulanır.

## Şema, güvenlik ve sicil

Yeni tablo yok. `org_result_revisions.match_protocol` özel sütunu zengin protokolü saklar; `protocol` ve `org_matches.result_protocol` eski score/sets/time/rank izdüşümünü taşır. 0097/0098 genel RPC'leri değişmez. Tam protokol, oyuncu referansları ve kadrolar anonim sonuçlara taşınmaz; ad/izin kuralı korunur.

Yayın, frozen roster revision ID'leri, yeni sonuç revizyonu, maç durumu, otomatik `athlete_achievements` ve audit aynı işlemde yazılır. Sporcu başına sonuç revizyonu tekildir. Başarı başlığı/sırası istemciden alınmaz. DQ/DNF derece üretmez; yarış sıraları seri bazındadır. Birden fazla seride yer alan sporcunun sicili seri sonuçlarını birlikte taşır, tek genel derece iddia etmez. Tek maç galibiyeti şampiyonluk/madalya sayılmaz; kaybeden tarafın kaydı maç kadrosu olarak etiketlenir.

Resmi başarılar mevcut guard ile update/delete'e kapalıdır. Sonuç revizyonu da append-only trigger ile korunur; yalnız FK temizliğinin actor_id null yapmasına izin verilir. Yeni düzeltme eski dereceyi değiştirmez, supersedes_id ile yeni kayıt üretir. Profil yalnız maçın güncel sonuç revizyonuna bağlı sicili gösterir. Tüm katılımcıların DQ/DNF olduğu düzeltme eski dereceyi profilden kaldırır, tarihçeyi silmez. Eski sonuçlara toplu geriye dönük derece üretilmedi.

Mevcut resmi tablo okuma RLS'i genişletilmedi. `official_athlete_achievements` ve `official_achievement_source` yalnız authenticated için açık, whitelist kullanan security definer RPC'leridir. Sporcu kendisi, bağlı veli veya sportif kulüp personeli okuyabilir. Salt muhasebecilik ve platform yöneticiliği açmaz. Görev iptali kendi/veli/kulüp sicil okumasını bozmaz. Misafir yalnız eski public program/sonuç RPC'lerini kullanır; özel CV'yi alamaz. Tüm yeni yardımcıların PUBLIC/anon/authenticated EXECUTE hakkı kaldırılır.

Mobil profil mevcut `AthleteProfileSection` üzerinden, sporcu detayı doğrudan ortak `OfficialAthleteCv` üzerinden sicili gösterir. Resmi satır yeşil SwanPalette.success kalkanı taşır, düzenleme/silme callback'i yoktur. Kaynak kartı resmi müsabaka, branş, tarih, yer, sonuç revizyonu ve sayısal periyot/devre/set satırlarını gösterir; tam kadro/oyuncu verisi taşımaz. Gayriresmi başarılar “Kulüp Beyanı” veya “Kulüp Gelişimi” olarak ayrılır. Mobilde SwanType/Palette/Space; konsolda projenin bilerek ayrı ConsoleDensity/Theme sözleşmesi kullanılır.

## Kanıtlar

Loglar workspace'in ignored `build/official-result-*.log` dosyalarındadır.

| Kontrol | Sonuç |
|---|---|
| swansport_data `flutter test --no-pub` | 364 geçti |
| swansport_app `flutter test --no-pub --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=` | 321 geçti |
| swansport_console `flutter test --no-pub` | 50 geçti |
| swansport_core `flutter test --no-pub` | 26 geçti |
| swansport_design_system `flutter test --no-pub` | 2 geçti |
| swansport_branch_engine `dart test` | 134 geçti |
| swansport_models `dart test` | 1 geçti |
| `node --test tools/federation_official_result_sql_test.mjs` | 21 geçti (16 temel + 5 yeni) |
| `node --test tools/federation_public_sql_test.mjs` | 28 geçti (16 ortak temel + 12 public) |
| Motor `dart analyze` | 0 bulgu |
| `flutter analyze --no-pub packages/swansport_data apps/swansport_console apps/swansport_app` | 0 hata, 5 önceden var olan kapsam dışı uyarı, 2888 info; çıkış 1 |
| 0103 pglast parse | 18 ifade |
| `python tools/check_faq.py` | 39/39 özellik yardımı |
| Git diff-check | geçti |

Toplam 763 Flutter ve 135 Dart testi geçti. SQL'de 49 senaryo koşusu vardır; iki dosyanın ortak 16 temel testi nedeniyle 33 farklı senaryo bulunur.

Yeni SQL testleri actual 0001/0002/0004/0011/0027/0094–0098 fonksiyonları ve 0103'ü izole PGlite PostgreSQL üzerinde, ilgisiz altyapısı azaltılmış fixture ile çalıştırır. Altı branşta gerçek yayın RPC'si → revizyon → otomatik sicil → veli CV okuması → anonim redaksiyon zinciri sınanır. Ayrıca sürüm çakışması, yetkisiz/admin yazımı, immutable kayıt, DQ düzeltmesi/itiraz dönüşü, PUBLIC/anon izinleri ve CV insert hatasında atomik rollback doğrulanır. Bu, canlı Supabase veya iki gerçek oturumlu eşzamanlılık UAT'si değildir.

Üretim web derlemeleri app ve konsolda main_production.dart + env/prod.json ile geçti; konsol base-href `/konsol/`. Her ikisinde mevcut CupertinoIcons font uyarısı var. Tarayıcıda hesaplı canlı UAT, Android APK/cihaz testi ve canlı dağıtım yapılmadı.

Not: core testlerinin bir dosyası flutter_test kullandığı için core `dart test` FFI derleyici hatası verdi; doğru Flutter runner ile 26/26 geçti. App testlerindeki boş Supabase define'ları mevcut derleme varsayılanlarının gerçek backend başlatmasını önler; bu görevde ürün ortam ayarı değiştirilmedi.

Başlangıçtaki `.flutter-plugins-dependencies` ve `docs/ROADMAP_FEDERATION_AND_IDENTITY.md` kullanıcı değişiklikleri korunmuş, görev commit'ine alınmamıştır.
