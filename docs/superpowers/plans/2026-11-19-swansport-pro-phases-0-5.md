# SwanSport Pro Faz 0–5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SwanSport Pro profesyonel işlemlerini Faz 0–5 sırasıyla gerçek liste, detay, işlem ve sonuç akışlarına tamamlamak.

**Architecture:** Mevcut `swansport_data` servis/RPC sözleşmeleri tek kaynak olarak kalır. `swansport_pro_features` ortak ekranları, Pro host yönlendirmesi ve App uyumluluk girişleri test-first biçimde genişletilir.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, Supabase/PostgreSQL, Flutter widget tests, Node/PGlite SQL tests.

**Spec:** `docs/superpowers/specs/2026-11-19-swansport-pro-phases-0-5-design.md`

## Global Constraints

- AGENTS.md değişmezleri ve beş noktalı feature flag sözleşmesi korunur.
- App ve Pro widget'ları doğrudan Supabase çağırmaz.
- App çalışan yönetim girişi Pro eşdeğeri kabul edilmeden kaldırılmaz.
- Kullanıcının mevcut dirty dosyaları ve unrelated kod değiştirilmez.
- Her davranış RED → GREEN ile doğrulanır; faz sonunda ilgili paket süiti çalışır.

## Review Focus

- Aynı başvurunun iki yönetici tarafından eşzamanlı sonuçlandırılması güncel durumu göstermeli, çift başarı göstermemeli.
- İmzalı belge URL'si hata/log/bildirim/görev metnine sızmamalı.
- Çalışma alanı veya kulüp değişiminde eski kapsam kayıtları görünmemeli.
- Branş/sporcu değişiminde bekleyen ölçüm yanlış kayda yazılmamalı.
- Pro kurulu değil veya rol uygun değilken App kullanıcıyı boş ekrana bırakmamalı.

---

### Task 1: Faz 0 — Mesleki Belge Başvuruları

**Files:**
- Modify: `packages/swansport_data/lib/src/verification_service.dart`
- Modify: `packages/swansport_pro_features/lib/src/platform/platform_parity_screens.dart`
- Modify: `packages/swansport_pro_features/lib/src/platform/platform_operations.dart`
- Modify: `apps/swansport_pro/lib/features/dashboard/pro_dashboard_screen.dart`
- Modify: `apps/swansport_pro/lib/features/operations/pro_tasks_screen.dart`
- Test: `packages/swansport_pro_features/test/phase4_specialist_platform_test.dart`
- Test: `apps/swansport_pro/test/pro_tasks_action_queue_test.dart`

**Interfaces:**
- Consumes: `pendingCredentialsProvider`, `documentsFor`, `reviewCredential`, `reviewLogProvider`, `sportlessCredentialsProvider`.
- Produces: çalışan Pro liste/detay/karar akışı ve Panel/Görevler girişi.

- [x] Yetkili/yetkisiz liste ve detay için kırmızı widget testlerini yaz ve beklenen nedenle başarısız olduklarını doğrula.
- [x] Belge önizleme hatası, onay, gerekçeli ret, çift dokunma ve stale/eşzamanlı karar testlerini RED doğrula.
- [x] En küçük servis ve UI değişiklikleriyle testleri geçir; sayaç/provider invalidation ve scroll/filter korunmasını bağla.
- [x] Pro/App/veri ilgili testlerini ve analizi çalıştır; Faz 0 kanıtını belgeye kaydet.

### Task 2: Faz 1 — Pro Ana Yüzeyleri

**Files:**
- Modify: `apps/swansport_pro/lib/features/dashboard/pro_dashboard_screen.dart`
- Modify: `apps/swansport_pro/lib/features/operations/pro_tasks_screen.dart`
- Modify: `apps/swansport_pro/lib/features/calendar/pro_calendar_screen.dart`
- Modify: `packages/swansport_pro_features/lib/src/inbox/shared_pro_inbox_screen.dart`
- Modify: `apps/swansport_pro/lib/features/account/pro_account_screen.dart`
- Test: `apps/swansport_pro/test/pro_device_matrix_test.dart`
- Test: `apps/swansport_pro/test/pro_tasks_action_queue_test.dart`

**Interfaces:**
- Consumes: Task 1 belge hedefi ve sayaçları.
- Produces: ortak özet/kuyruk/detay başlık ve geri gezinme düzeni.

- [x] En kısa rol bazlı Panel hedefleri, görev sıralaması ve scope değişimini mevcut sözleşme testleri ve Faz 0 hedef testiyle doğrula.
- [x] Inbox desteklenen bildirimlerini kayıt/filtre hedefine bağlayan testleri doğrula.
- [x] Ortak Pro bileşenleriyle mobil/geniş yerleşim testlerini geçir.
- [x] Faz 1 kabul ve responsive kanıtını kaydet.

### Task 3: Faz 2 — Kulüp ve Antrenman Operasyonları

**Files:**
- Modify: `apps/swansport_pro/lib/features/operations/pro_club_management_screen.dart`
- Modify: `packages/swansport_pro_features/lib/src/roster/*`
- Modify: `packages/swansport_pro_features/lib/src/attendance/*`
- Modify: `packages/swansport_pro_features/lib/src/training/*`
- Modify: gerekli `packages/swansport_data/lib/src/*` servisleri
- Test: ilgili Pro features ve App parite testleri

**Interfaces:**
- Consumes: Task 2 ortak liste/detay chrome.
- Produces: üyelik, evrak, takım/kadro, yoklama ve antrenman tam zincirleri.

- [x] Üyelik ve gerçek evrak davranışlarının mevcut ayrı sözleşme testlerini doğrula.
- [x] İki branş, grup/sporcu ölçümü ve sporcu değişiminde kirli ölçüm korumasını RED doğrula.
- [x] Minimum uygulamayla Pro zincirini tamamla; App bireysel/katılım/veli sonuç girişlerini koru.
- [x] Faz 2 rol, veri ayrımı ve hesapsız sporcu kabulünü çalıştırıp kaydet.

### Task 4: Faz 3 — Kalan Operasyon Modülleri

**Files:**
- Modify: ilgili guardian/accounting/facility/referee/federation ortak ekranları ve Pro görev hedefleri
- Test: her modülün mevcut test dosyası

**Interfaces:**
- Consumes: Task 2 ortak chrome ve Task 3 doğrudan kayıt hedefi yaklaşımı.
- Produces: beş modülde Pro'dan tamamlanan ana işlem.

- [x] Veli, finans, tesis, hakem ve federasyon ana işlemlerinin mevcut tam zincir testlerini sırayla çalıştır.
- [x] Muhasebeci maskelemesini ve tüm kapsam kapılarını doğrula.
- [x] Görev kartlarının kayıt veya filtrelenmiş liste hedeflerini doğrula.
- [x] Her modül kabulünü ve kalan sınırları kaydet.

### Task 5: Faz 4 — App/Pro Görev Ayrımı ve Fallback

**Files:**
- Modify: `apps/swansport_app/lib/features/pro_operations/swan_pro_feature_host.dart`
- Modify: App yönetim girişleri ve route-link uyumluluk katmanı
- Test: App host parite, merged route ve notification route testleri

**Interfaces:**
- Consumes: Task 1–4'te kabul edilmiş Pro hedefleri.
- Produces: Pro ana işlem hedefleri ve güvenli App fallback'leri.

- [x] Her profesyonel işin App kısayol/eski rota/bildirim/hedef sonucunu test tablosuyla doğrula.
- [x] Yalnız doğrulanmış işleri Pro'da tut; başvuru ve öz-servis girişlerini koru.
- [x] Rol uygunsuz/legacy bildirim ve ortak host fallback senaryolarını geçir.
- [x] Faz 4 görev matrisini güncelle.

### Task 6: Faz 5 — Uçtan Uca Kabul ve Teslim

**Files:**
- Modify: `docs/swansport-pro-management-parity-matrix.md`
- Create: `docs/swansport-pro-phases-0-5-verification.md`
- Create/Modify: responsive görsel kabul testleri

**Interfaces:**
- Consumes: Task 1–5 tüm kullanıcı akışları.
- Produces: son matris, kanıt raporu ve mobil/geniş ekran görselleri.

- [x] Başvuran→Pro yönetici→App sonuç ve antrenör→sporcu/veli rol zincirlerini çalıştır.
- [x] Eski bildirim, geçmişsiz açılış, geri dönüş ve kapsam değişimi senaryolarını çalıştır.
- [x] AGENTS.md analiz/test kontrollerini ve responsive capture'ları çalıştır.
- [x] Son rapora değişen dosyaları, test sonuçlarını ve cihaz/canlı sınırlarını kaydet.
