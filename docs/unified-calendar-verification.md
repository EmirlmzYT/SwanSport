# Birleşik Takvim — yerel uygulama ve doğrulama

2026-10-10. Resmi faaliyetler, müsabakalar ve yetkili kulüp kayıtları mevcut takvimde birleşir. Yeni tablo, resmi kayıt kopyası veya resmi yazma ekranı oluşturulmaz.

## Uygulama

- `0102_unified_calendar.sql`: `public_federation_activities` yalnız `official AND is_public` organizasyonları, bağlı faaliyet yılı/ofis/federasyon ve maç metadatasıyla projekte eder. Branş, il, sezon ve tarih filtreleri vardır. Ulusal faaliyetler il filtresinde de görünür. PUBLIC execute kaldırılır; yalnız anon/authenticated genel RPC'yi çağırabilir. Tabloya anon SELECT verilmez. Mevcut yayın ve sonuç RPC'leri değişmez.
- `my_calendar_club_entries`: oturum ve en fazla 370 günlük geçerli aralık ister. Aktif kulüp üyelerinin mevcut kulüp okuma kapsamı korunur; veli yalnız bağlı çocuğun kulübü/takımı kapsamındadır. Salt muhasebeci veya platform yönetici olmak erişim vermez. İç yardımcı RPC doğrudan çağrılamaz.
- `events` ve `training_sessions.started_at` birlikte okunur. Etkinliğe bağlı oturum aynı etkinliği ikinci kez üretmez; kişisel oturumlar, sporcu kimlikleri ve katılım kodları projeksiyonda yoktur. Gizli takım etkinliği görünür takım oturumu üzerinden sızmaz. Resmi maç `events` tablosuna kopyalanmaz.
- Riverpod ay/gün/tür/yer filtrelerini ve kronolojik birleştirmeyi veri paketinde yönetir. Misafir özel sağlayıcıyı oluşturmaz. Kaynaklardan biri hata verirse diğeri gösterilir ve hata açıkça belirtilir; örnek kayıt üretilmez. Oturum kapanınca kulüp verileri birleşik listeden çıkar.
- Türkiye takvimi kullanılır. Çok günlük faaliyetin son tarihi dahildir; modelde bitiş sonraki günün gece yarısıdır ve hariç tutulur. Aynı saatli kayıtlar sabit kimlikle sıralanır.
- `/calendar` ve eski `/federasyon-takvimi` aynı ekranı kullanır. Ay hücreleri tür işaretleri, üç filtre, resmi rozet ve yer/tarih/kategori/durum detay penceresi vardır. Mevcut kulüp RSVP ve kulüp maç sonucu formu korunur; resmi detay salt okunurdur. Mevcut tasarım jetonları kullanılır.

## Test kanıtı

Loglar çalışma alanındaki `build/unified-calendar-*.log` dosyalarındadır; canlı sisteme test yapılmaz.

| Kontrol | Sonuç | Log |
|---|---|---|
| Veri paketi tam `flutter test --no-pub` | 360/360 | `unified-calendar-all-data.log` |
| Konsol tam `flutter test --no-pub` | 46/46 | `unified-calendar-console.log` |
| Uygulama tam test, boş bağlantı define'larıyla | 317/317 | `unified-calendar-app-final.log` |
| Gerçek SQL + public regresyon | 49/49 | `unified-calendar-sql-regressions.log` |
| Aylık ekran, filtre, detay ve viewport hedef turu | 12/12 | `unified-calendar-ui-final.log` |
| 0102 SQL parse | 10 SQL ifadesi başarılı | pglast |
| SSS özellik kapsamı | 39/39 | `python tools/check_faq.py` |
| Genel Flutter analyze: app/data/console | 0 hata, 5 önceki uyarı, 2778 info; çıkış 1 | `unified-calendar-full-analysis.log` |

SQL turu `node --test tools/unified_calendar_sql_test.mjs tools/federation_public_sql_test.mjs` ile çalışır. 5 yeni takvim senaryosu, 12 public senaryosu ve her giriş noktasından çalıştırılan 16 temel senaryo vardır; temel senaryolar iki kez çalıştığından toplam 49'dur. Yeni takvim testleri gerçek 0094–0097 migrasyonlarını ve 0071 protokol/oturum DDL'sini kullanır; ilgisiz altyapı azaltılmış yerel fixture'dır. Bu, tüm üretim migration zinciri veya canlı RLS/UAT doğrulaması değildir.

Tam uygulama testi şu komutla izole edilir:

```powershell
flutter test --no-pub --dart-define=SUPABASE_URL= --dart-define=SUPABASE_ANON_KEY=
```

Projedeki mevcut `SupabaseConfig.fromCompileTime` varsayılanları doludur. Çıplak komutla ilk turda eksik yapılandırma/çevrimdışı başlangıç bekleyen dört eski test başarısız oldu; bu görev core yapılandırmasını değiştirmez. Sonraki tur küçük ekranda gün başlığı taşmasını yakaladı; Wrap ile düzeltildi ve 375–1440px/açık-koyu tema hedef testleri geçti. Son tam uygulama turunda 317/317 geçti; sporcu RSVP görünümü ve antrenörün mevcut kulüp maç sonucu formu ayrıca sınandı. Toplam 360 veri + 317 uygulama + 46 konsol = 723 Flutter testi başarılıdır.

Genel analizdeki beş uyarı değişmeyen `role_context_switcher.dart`, `marketplace_screen.dart`, konsol `marketplace_admin_screen.dart`, `marketplace_service.dart` ve `social_and_lifecycle_test.dart` içindedir. Değişen üretim takvim dosyalarında hata/uyarı yoktur; mevcut stil info'ları başarı gibi gizlenmez. Graph indeksi 2026-10-07 olduğundan yeni/değişen kaynaklar doğrudan dosya okumalarıyla doğrulanmıştır. `git diff --check` başarılıdır.

## Sınırlar

- 0102 canlı Supabase'e uygulanmadı; uzak ortam bu RPC'lere sahip olana kadar ekran yükleme uyarısını gösterir. Otomatik yayımlama yoktur.
- Yıllık program oluşturma/düzenleme, federasyon konsolu, ferdi sporcu kaydı ve hesap silme bu görevin kapsamı değildir. Mevcut program türü/kategori/yer değerleri gösterilir; eksik alan uydurulmaz.
- Canlı hesaplı UAT, deploy ve push yapılmadı. Kullanıcıya ait `docs/ROADMAP_FEDERATION_AND_IDENTITY.md` ve generated plugin metadata korunur.
