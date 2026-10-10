# Evrensel antrenman arketipleri — yerel doğrulama

2026-10-10. Bu görev motor, SQL ve ortak veri katmanını kapsar. Yeni ekran, canlı SQL, deploy veya Git push yapılmadı. Canlı veritabanının önceki sürümü 0104'tür; 0105 yerel dosyadır.

## Uygulama sözleşmesi

Mevcut şemada yapılandırmanın sahibi **training_protocols.config**, sonuçların sahibi **training_sets** tablosudur. `training_sessions.config` veya `training_set_scores` adında ikinci yapı kurulmadı. Mevcut `TrainingProtocolConfig` ve `TrainingSet` tipleri genişletildi. Protokol sürümlemesi ve eski oturumların değişmezliği korunur.

| Arketip / JSON değeri | Örnek branşlar | Fazlar | Tipli metrik |
|---|---|---|---|
| Target Score / `target_score` | Okçuluk, atıcılık | Eski prep → shoot → collect → score → rest → done | X/M ve 0–10 halkaları |
| Attempt Drill / `attempt_drill` | Voleybol, basketbol, futbol | prep → active_drill → rest → prep; son tekrar → done | Drill adı, başarı, hata, deneme, türetilen başarı oranı |
| Lap Interval / `lap_interval` | Yüzme, koşu/atletizm, kürek | prep → lap_active → rest_interval → prep; son tur → done | Tur, tam sayı milisaniye, mesafe, isteğe bağlı kulaç frekansı |
| Combat Rally / `combat_rally` | Tenis, boks, eskrim | prep → active_drill → rest → prep; son tekrar → done | Ralli, winner, basit hata |

`TrainingPhase`, mevcut `SessionPhase` enum'ının takma adıdır; `completed` eski `done` değerini temsil eder. Bitirilen oturum yine önce `review`, antrenör kilitlemesinden sonra `completed` durumuna geçer. Sıfır dinlenme atlanır. Yeni aktif/dinlenme fazları `shoot_seconds` / `rest_seconds` sürelerini kullanır; mevcut sayaç sözleşmesi değişmez. Sunucu gerçek otorite, Dart geçişi önizlemedir.

`archetype` bulunmayan eski config hedef puanlamasıdır. `collect_seconds` yalnız hedefte zorunludur; diğerlerinde verilirse doğrulanır fakat faz akışına alınmaz. Dört arketipte ortak set/süre sınırları sürer. Bilinmeyen arketip veya metrik anahtarı reddedilir. JSON tipleri, tam sayı/aralık koşulları ve deneme/ralli tutarlılığı kontrol edilir. `20.0` gibi tam sayı değerindeki JSON sayıları güvenli dönüştürülür; kesirli sayaçlar reddedilir.

`metric_payload` mevcut setlerde `{}` varsayılanıyla bulunur. Eski dört parametreli `submit_set_score` çağrıları beşinci parametrenin varsayılanıyla çalışır; eski imza düşürülür, ikinci overload kalmaz. Hedef metrikleri sunucuda puana çevrilir; X ve M ayrıca korunur. Deneme/ralli toplamları metrikten türetilir. Tur milisaniyesi puan olarak toplanmaz; metrikli tur tamamlanmış set sayılır ve hedeflenen tur sayısı set sayısıdır. Eski boş sonuç/sıfır ayrımı korunur.

Kilitli metrik düzeltmesi mevcut `correct_locked_set` RPC'sinden, gerekçe ve doğrulanmış yeni metrikle yapılır. Eski/yeni metrik mevcut denetim izine yazılır; scalar skorla metrik ayrıştırılamaz. Gönderme, ilerletme, kilitleme ve düzeltme oturum → set kilit sırasını kullanır. Eski scalar düzeltme yolu korunur.

Antrenör notları ikinci bir defter açmadan `training_session_events`, `action='drill_note'` içinde tutulur. `submit_coach_drill_note` mevcut yönetim yetkisini, kulüp oturumunu, durumunu ve aktif katılımcıyı doğrular. Yardımcı antrenörlere yeni kademe sınırı getirilmez. Kişisel oturumun sahibi antrenör notu yazamaz. Mevcut özel okuma RLS'i korunur; `sessionCoachDrillNotesProvider` son 200 notu okur. Sporcu silinirse olayın nullable sporcu referansı okuyucuyu çökertmez.

0105 dosyasının ilk ifadesi `set local lock_timeout = '15s'` olur. Tüm değişen/yeni RPC'lerde PUBLIC/anon/authenticated izinleri açıkça temizlenir; istemci fonksiyonları yalnız authenticated'a açılır. İç faz/metrik yardımcıları özel kalır. Anon'a tablo veya RPC okuması açılmaz. Bayrak ve mevcut SSS yayın kapısı değiştirilmedi.

## Doğrulama kanıtı

| Kontrol | Sonuç | Yerel log |
|---|---|---|
| Saf Dart motorunun tüm testleri | **163 geçti**; önceki 134 + yeni 29 | `build/training-engine-test.log` |
| swansport_data tüm Flutter testleri | **387 geçti** | `build/training-all-data-test.log` |
| Mobil/web uygulaması tüm Flutter testleri | **330 geçti** | `build/training-all-app-test.log` |
| Konsol tüm Flutter testleri | **50 geçti** | `build/training-all-console-test.log` |
| Son biçimlendirmeden sonra eski/yeni antrenman veri testleri | **40 geçti**, yukarıdaki 387'nin alt kümesi | `build/training-data-focused-test.log` |
| İzole PostgreSQL/PGlite davranış testleri | **17 geçti** | `build/training-sql-test.log` |
| Motor analizi | **Bulgu yok** | `build/training-engine-analyze.log` |
| Değişen veri servisi/yeni veri testi analizi | **0 hata, 0 uyarı, 20 stil info** | `build/training-data-analyze.log` |
| 0105 PostgreSQL parse / SSS / git diff kontrolü | Başarılı; 39/39 yardım kapsamı | `build/training-faq-check.log` |

Toplam: **767 Flutter + 163 Dart + 17 PostgreSQL senaryosu**. 40 tekrar toplam sayıya eklenmedi. Loglar build altında, Git dışında tutulur.

SQL testleri gerçek 0001/0002/0004 ve 0071/0072/0074 kaynaklarını izole bir fixture üzerinde çalıştırır; ilgisiz etkinlik/uygunluk/performans altyapısı fixture'da sınırlı biçimde temsil edilir. 0105'in yeniden uygulanması, tek RPC imzası, ACL/RLS, NULL/yanlış JSON tipleri, eski okçuluk, dört akış, sıfır dinlenme, duraklatma, tamamlanma sayımı, kilitli upsert reddi, düzeltme audit'i ve not yetkileri gerçekten çalıştırılır. Bu sonuç canlı Supabase veya iki bağımsız bağlantılı kilit yarışı testi iddiası değildir.

Yeniden çalıştırma:

```powershell
# packages/swansport_branch_engine içinde
dart test
dart analyze
# packages/swansport_data içinde
flutter test
# apps/swansport_app içinde; testlerin canlıya bağlanmaması için
flutter test --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=
# apps/swansport_console içinde
flutter test
# depo kökünde; mevcut PGlite test çalışma ortamını kullanır
node --test tools/training_archetypes_sql_test.mjs
python tools/check_migrations.py supabase/migrations/0105_training_drill_archetypes.sql
```

Motor pubspec'ine Flutter/Supabase bağımlılığı eklenmedi; branş sözleşmeleri ve okçuluk tanımı değiştirilmedi. Graph kapsamı eski/kısmi olduğundan keşif sonuçları güncel kaynak ve testlerle doğrulandı. Canlıya geçiş ayrıca istendiğinde önce 0105 kendi transaction'ında, sonra yeni istemci uygulanmalıdır. Bu görev arketip seçici, sayaç giriş ekranı veya drill pad arayüzünü eklemez.
