# SwanSport Pro Faz 4 Uygulama Planı — Muhasebe, Tesis, Uzman Personel ve Platform Operasyonları

**Tarih:** 2026-10-27
**Başlangıç Commit (Taban):** `bf505d2` (`codex/advanced-chat-header46`)
**Hedef Sürüm:** `0.1.3+5` (`com.swansport.pro`)

## İLERLEME
- [x] Dilim 1  - [x] Dilim 2a  - [x] Dilim 2b  - [x] Dilim 2c
- [x] Dilim 3a  - [x] Dilim 3b  - [x] Dilim 3c   - [x] Dilim 4a (envanter)  - [x] Dilim 4b (sağlık)  - [x] Dilim 4c (sportif)
- [x] Dilim 5a (salt okunur ekranlar)  - [x] Dilim 5b (waitlist/plan yazıları)
- [x] Dilim 6  - [x] Dilim 7  - [x] Dilim 8

## 1. Hedef ve Değişmez Kurallar

SwanSport Pro içindeki `ProWorkspace.accounting`, `ProWorkspace.facility`, `ProWorkspace.platform` ve kulüp ihtisas personeli operasyonlarını (`Envanter ve zimmet`, `Sağlık ve idari dinlendirme`, `Sportif kadro planlama`), `packages/swansport_pro_features` ortak operasyon paketi üzerinden gerçek veri ve sunucu sözleşmelerine bağlamak; bu süreçte SwanSport Ana Sayfa görünümüne, sosyal gezinmeye, mevcut SwanSport rotalarına ve masaüstü Console işlevlerine dokunmamak.

- **Tek Yetki Kaynağı:** `SwanAccess` görünürlüğü belirler; gerçek güvenlik mevcut RLS politikaları ve `security definer` RPC'lerdedir. Feature flag güvenlik değildir.
- **Veri Katmanı Sınırı:** Tüm Supabase sorguları ve Riverpod provider'ları `packages/swansport_data/lib/src/` içinde kalır. Widget'lar veya `swansport_pro_features` doğrudan Supabase çağrısı yapmaz.
- **Paket Sınırı:** `packages/swansport_pro_features` hiçbir uygulama paketini (`swansport_app`, `swansport_pro`) veya ham uygulama rota dizgesini import/referans etmez; tipli `ProFeatureNavigator` (`PlatformWebConsoleSection` enum dahil) ve `ProFeatureChrome` portlarını kullanır.
- **Muhasebeci Gizliliği:** Muhasebeci `athletes` tablosunu veya sporcu adlarını okumaz; yalnız `acc_*` projeksiyonları ve `athlete_ref` / `athleteCode` maskeli referanslar kullanılır. Onaylı, beklenen ve belirsiz nakit ayrı gösterilir; belirsiz tutarlar kesin bakiyeye eklenmez.
- **Sağlık Sınırı:** Doktor etiketi tek başına sağlık yetkisi vermez; `hasMedicalAuthorityForClub` otoritesi kullanılır. Teşhis veya klinik not tutulmaz; idari dinlenmenin kaldırılması tıbbi kilidi kaldırmaz.
- **Envanter ve İdempotensi:** Mevcut `0114` RPC ve `operationId` sözleşmeleri kullanılır; belirsiz ağ yanıtında yeni `operationId` üretilmez, aynı `operationId` ve aynı payload ile retry yapılır.
- **Platform Sınırı:** Yalnız `isPlatformAdmin` ile açılır; sır/API anahtarı/Firebase bilgisi gösterilmez; masaüstü yoğun işlemler tipli `openPlatformWebConsole` (`PlatformWebConsoleSection`) ile web konsoluna yönlendirilir.

## 2. Uygulama Dilimleri ve Commit Sırası

### Dilim 1 — `feat(pro): scaffold finance and specialist operations`
- `ProFeatureNavigator` ve `ProFeatureNavigatorBase` arayüzlerine Faz 4 tipli navigasyon kontratlarının (`openFinanceOperations`, `openFinanceLedger`, `openFinanceCommitments`, `openBankReconciliation`, `openClubBudget`, `openPeriodClosing`, `openFacilityOperations`, `openClubInventory`, `openClubHealthOperations`, `openClubSportingPlanning`, `openPlatformOperations`, `openPlatformWebConsole([PlatformWebConsoleSection])`) eklenmesi.
- `ProFeatureContextKey` üzerinde muhasebe kulüp kapsamı (`accounting`), tesis kapsamı (`facility`) ve platform çalışma alanı (`platform`) kurucularının tanımlanması.
- `ProDirtyStateCoordinator` üzerinde belirsiz işlem (`markPendingOperation` / `hasPendingOperation`) korumasının ve `proFeatureInvalidationTargets` / `invalidateProFeatureState` içinde yalnız Faz 4'te gerçek tüketicisi olan scoped provider'ların tanımlanması.
- `tools/pro_features_contract_test.py` ve `packages/swansport_pro_features/test/` sınır/context/dirty-state testlerinin TDD ile eklenmesi.

### Dilim 2 (2a / 2b / 2c) — `feat(pro): add accountant operations workspace`
- **2a:** `SharedAccountingOperationsPanel`, `SharedFinanceOperationsScreen` ve `SharedFinanceLedgerScreen` (`isAccountant` kapısı, muhasebeci kulüp seçici, `acc_*` maskeli defter ve özet kuyruk).
- **2b:** `SharedFinanceCommitmentsScreen` ve `SharedBankReconciliationScreen` (tekrarlayan gider/taahhütler, kendi giderini onaylama engeli, banka ekstre hareketleri ve eşleşme önerileri).
- **2c:** `SharedClubBudgetScreen`, `SharedPeriodClosingScreen` (onaylı/beklenen/belirsiz nakit ayrımı, kapanış kontrol listesi, kapalı dönemde doğrudan düzenleme yerine ters kayıt/düzeltme akışı) ve SwanSport mobil host sarmalayıcıları.

### Dilim 3 — `feat(pro): add facility operations workspace` [x]
- `SharedFacilityOperationsPanel`, `SharedManagedTurfDutiesScreen`, `SharedFacilityScheduleScreen`, `SharedFacilityReservationsScreen`.
- `SwanAccess.canOpenTurfCenter` kapısı, `managedTurfFieldIds` ve `delegatedTurfFieldIds` ayrımı, süresi geçmiş görevlerde fail-closed davranış, gerçek UUID ve zaman aralığı olmadan çakışma için `'Doğrulanamıyor'` gösterimi.

### Dilim 4 (4a / 4b / 4c) — `feat(pro): add specialist staff operations`
- **4a:** `SharedClubStaffOperationsPanel` ve `SharedClubInventoryScreen` (`canReadClubInventory` / `canManageClubInventory`, maskeli hedef referansı, hesapsız sporcular için takım zimmeti, aynı `operationId` ile retry).
- **4b:** `SharedClubHealthOperationsScreen` (`canReadClubHealth`, `canManageAdministrativeStatus`, `hasMedicalAuthorityForClub`, idari dinlenmenin tıbbi kilidi kaldırmaması, klinik not/teşhis tutmama).
- **4c:** `SharedClubSportingPlanningScreen` (`canReadClubPlanning`, kadro/lisans/yoklama özeti, `FeatureFlags.developmentReport` entegrasyonu, sahte transfer kuyruğu üretmeme) ve `apps/swansport_app` host sarmalayıcısı.

### Dilim 5 (5a / 5b) — `feat(pro): add platform mobile operations`
- **5a:** `SharedPlatformOperationsPanel`, `SharedPlatformStatusScreen`, `SharedPlatformAuditScreen` (`isPlatformAdmin` kapısı, sır içermeyen public config, bakım/broadcast ayarının global backend kill-switch olmadığının açık gösterimi, sayfalı salt okunur audit).
- **5b:** `SharedPlatformPlansScreen` ve `SharedLaunchWaitlistScreen` (onaylı ve güncel hesap kontrollü waitlist bildirildi işlemi, plan doğrulama/audit, masaüstü yoğun işlemler için tipli `openPlatformWebConsole(PlatformWebConsoleSection)` yönlendirmesi).

### Dilim 6 — `feat(pro): wire phase four workspaces`
- `ProWorkspace.accounting`, `facility` ve `platform` çalışma alanlarının `ProDashboardScreen`, `ProTasksScreen`, `ProRouter` ve dar kapsamlı gate bileşenlerine (`ProAccountingOperationsGate`, `ProFacilityOperationsGate`, `ProPlatformOperationsGate`, `ProClubSpecialistOperationsGate`) bağlanması.
- `apps/swansport_pro/pubspec.yaml` sürümünün `0.1.3+5` yapılması.

### Dilim 7 — `test(pro): preserve phase four host parity`
- Muhasebe gizliliği, tesis yönetici/delege ayrımı, uzman personel yetki/idempotensi sınırları, platform admin/web-console yönlendirmesi, 320px / 2.0 text scale, 48dp dokunma hedefleri ve iki-host parite testlerinin tamamlanması.

### Dilim 8 — `docs(pro): verify phase four professional operations`
- Tüm zorunlu Python kontrat, SQL ve Flutter analyze/test/build kontrollerinin çalıştırılması ve `docs/swansport-pro-phase-4-verification.md` doğrulama raporunun oluşturulması.
