# SwanSport Pro Faz 3 Uygulama Planı — Federasyon, Hakem ve Resmî Müsabaka Operasyonları

**Tarih:** 2026-10-27
**Başlangıç Commit (Taban):** `0ef0bab` (`codex/advanced-chat-header46`)
**Hedef Sürüm:** `0.1.2+4` (`com.swansport.pro`)

## 1. Hedef ve Mimari İlkeler

SwanSport Pro içindeki `ProWorkspace.federation` ve `ProWorkspace.referee` çalışma alanlarını, `packages/swansport_pro_features` ortak operasyon paketi üzerinden gerçek veri ve sunucu sözleşmelerine bağlamak; bu süreçte SwanSport Ana Sayfa görünümüne, sosyal gezinmeye, mevcut SwanSport rotalarına ve masaüstü Console işlevlerine dokunmamak.

- **Tek Yetki Kaynağı:** `SwanAccess` görünürlüğü belirler; gerçek güvenlik mevcut RLS politikaları ve `security definer` RPC'lerdedir.
- **Veri Katmanı Sınırı:** Tüm Supabase sorguları ve Riverpod provider'ları `packages/swansport_data` içinde kalır. Widget'lar veya `swansport_pro_features` doğrudan Supabase çağrısı yapmaz.
- **Paket Sınırı:** `packages/swansport_pro_features` hiçbir uygulama paketini (`swansport_app`, `swansport_pro`) veya ham uygulama rota dizgesini import/referans etmez; tipli `ProFeatureNavigator` ve `ProFeatureChrome` portlarını kullanır.
- **Durum İzolasyonu:** Hesap, çalışma alanı veya federasyon/kulüp kapsamı değiştiğinde `ProFeatureContextBoundary`, `ProDirtyStateCoordinator` ve `invalidateProFeatureState` üzerinden geçici state ve rapor taslakları temizlenir.

## 2. Uygulama Dilimleri ve Commit Sırası

### Dilim 1 — `feat(pro): scaffold federation and referee operations`
- `ProFeatureNavigator` ve `ProFeatureNavigatorBase` arayüzlerine federasyon ve hakem navigasyon kontratlarının eklenmesi (`openFederationMatches`, `openRefereeAssignments`, `openLeagueStandings`, `openDisciplinaryBoard`, `openFederationBulletins`, `openRefereeDuties`, `openRefereeLineup`, `openRefereeLiveCockpit`, `openRefereeMatchReport`).
- `ProFeatureContextKey` içine opsiyonel `scopeId` alanının eklenmesi; `proFeatureInvalidationTargets` ve `invalidateProFeatureState` fonksiyonuna federasyon/hakem provider'larının ve yerel taslak state'lerinin eklenmesi.
- Federasyon kapsam seçimi (`selectedFederationScopeProvider`) ve kullanıcıya/maça izole hakem rapor taslağı (`refereeReportDraftProvider`) state sağlayıcılarının oluşturulması.
- `tools/pro_features_contract_test.py` ve `packages/swansport_pro_features/test/` sınır testlerinin Faz 3 kurallarıyla genişletilmesi.

### Dilim 2 — `feat(pro): add federation operations workspace`
- `SharedFederationOperationsPanel` ve `SharedFederationMatchesScreen` bileşenlerinin `packages/swansport_pro_features/lib/src/federation/` altında oluşturulması.
- `SwanAccess.canOpenFederationOperations` yetki kapısı, çoklu federasyon/il kapsam seçici, sunucu taraflı arama/il/hafta filtresi ve sayfalama (`FederationMatchQuery`).
- `apps/swansport_pro` içinde `ProWorkspace.federation` çalışma alanının `ProDashboardScreen`, `ProTasksScreen`, `ProShell`, `ProRouter` ve `ProFederationContextSelector` ile bağlanması.

### Dilim 3 — `feat(pro): add official assignment workflows`
- `SharedRefereeAssignmentsScreen` ve atama diyaloğunun oluşturulması.
- Başkan ve MHK üyeleri için aktif branş/il hakem aday listesi (`federationAvailableRefereesProvider`), son maç tarihi, görev atama (`assignMatchOfficial`) ve imzalı maç raporu özeti (`federationLockedReportProvider`).
- İl temsilcisi (`provincial_rep`) için salt okunur görünüm ve özel ret nedeninin (`declineReason`) gizlenmesi.
- Kesin tesis tahsisi/süresi olmayan maçlarda çakışma durumunun `0` uydurulmadan `'Doğrulanamıyor'` olarak gösterilmesi.

### Dilim 4 — `feat(pro): add league and discipline operations`
- `SharedLeagueStandingsScreen`: `SwanAccess.canViewProvincialLeagues` ve `FeatureFlags.leagueStandings` kapıları, organizasyonun gerçek `winPoints/drawPoints/lossPoints` değerleri, resmi/canlı tablo geçişi, eksik kural/veri durumlarının açık gösterimi.
- `SharedDisciplinaryBoardScreen`: `SwanAccess.isDisciplinaryBoardMember` kapısı, imzalı hakem raporu kuyruğu, maskeli sporcu referansı (`athlete.reference`), idempotent ve immutable ceza kararı (`recordDecision` + `p_operation_id` retry koruması).
- `SharedFederationBulletinsScreen`: `FeatureFlags.federationBulletin` kapısı, kamusal `public_summary` disiplin bülteni ve resmi müsabaka duyurularının özel disiplin gerekçelerinden ayrı gösterimi.

### Dilim 5 — `feat(pro): add referee duty and lineup flows`
- `SharedRefereeOperationsPanel`, `SharedRefereeDutyListScreen` ve `SharedRefereeLineupApprovalScreen` bileşenlerinin oluşturulması.
- `SwanAccess.isReferee` ve `FeatureFlags.refereeCockpit` kapıları; geçersiz UUID rotalarda (`isPublicMatchId`) backend çağrısı yapmadan güvenli hata gösterimi.
- Görev kabul/ret (`respondMatchAssignment`), mazeret diyaloğunda `RefereeActorScope` ve kirli durum koruması.
- Esame ekranında sunucu taraflı `match_approved_lineups` ve `referee_lineup_candidates` kullanımı; çocuk/veli gizlilik maskesinin (`name ?? maskedRef`) ve uygunluk rozetlerinin (`medical`, `suspended`, `rested`, `license`) korunması; `verifyMatchLineup` ile kilitleme.

### Dilim 6 — `feat(pro): add referee live match reporting`
- `SharedRefereeLiveCockpitScreen`: Futbol, basketbol ve tenis protokolleri (`refereeSupportsLive`); bireysel branşlarda sahte skor üretmeme; append-only olaylar (`score`, `clock_start`, `clock_pause`, `card`, `substitution`, `period_end`, `undo`).
- Belirsiz ağ yanıtlarında aynı `operation_id` ve payload ile yeniden deneme (`refereeMutationProvider`); sunucu onayı olmadan skoru kesinleşmiş göstermeme; dispose'da kapanan 1s kronometre ticker'ı.
- `SharedRefereeMatchReportScreen`: Kullanıcı ve maça özel RAM taslağı (`refereeReportDraftProvider`), ağ hatasında taslağı koruma, hesap/workspace değişiminde taslağı sıfırlama, idempotent ve immutable rapor gönderimi (`referee_submit_match_report`).

### Dilim 7 — `test(pro): preserve federation host parity`
- Pro sürümünün `0.1.2+4` yapılması; `tools/pro_app_contract_test.py`, `build_pro_preview.yml` ve `build_pro_production_preview.yml` güncellemeleri.
- Yetki, gizlilik, feature flag, UUID doğrulama, retry/idempotency, timer dispose, 320px / 2x text scale erişilebilirlik, 48dp hedef ve iki-host parite testlerinin tamamlanması.
- SwanSport Ana Sayfa, sosyal navigasyon, mevcut mobil rotalar ve Console ekranlarında regresyon olmadığının doğrulanması.

### Dilim 8 — `docs(pro): verify phase three official operations`
- Tüm paket analizleri, birim/widget testleri, Node SQL testleri, Python sözleşme testleri ve web release build doğrulamalarının çalıştırılması.
- `docs/swansport-pro-phase-3-verification.md` doğrulama raporunun oluşturulması ve commit'lenmesi.
