# SwanSport — Faz 4: Masaüstü Yönetim Konsolu (Federasyon, İl Temsilciliği & MHK) Codex Uygulama Şartnamesi

**Tarih:** 2026-10-13
**Kapsam:** `apps/swansport_console` içinde Federasyon Başkanı, İl Temsilcileri ve MHK için masaüstü yönetim modülleri (MHK Hakem Atama Matrisi, İl Lig Yönetimi, Disiplin Kurulu Sevk ve Ceza Paneli).

---

## 1. Mimari Prensipler ve Değişmezler (Invariants)

1. **Yalnızca Masaüstü / Web (≥900px):**
   - `swansport_console` masaüstü web içindir; mobil sosyal bileşenleri buraya taşınamaz.
   - Tasarım sistemi: Konsolun kendi `swansport_design_system` paketi ve `ConsoleTable`, `StatusPill`, `ConsoleModule` bileşenleri kullanılır.
2. **Yetkilendirme Sözleşmesi (`SwanAccess`):**
   - `ConsoleAudience.federation`: Federasyon Başkanı, İl Temsilcisi, MHK üyesi veya Disiplin Kurulu üyeleri için açılır.
   - `isFederationPresident`: Tüm illeri ve modülleri görür.
   - `isProvincialRep`: Yalnızca kendi ilindeki (`cityCode`) maçları ve ligleri görür.
   - `isRefereeCommitteeMember`: Hakem atama matrisine tam erişir.
   - `isDisciplinaryBoardMember`: Disiplin sevk ve ceza kararları modülüne erişir.
3. **Gizlilik ve Sınırlar:**
   - Hakemlerin mazeret bildirme gerekçeleri yalnızca MHK ve Federasyon Başkanına görünür; kulüplere veya kamuoyuna sızdırılamaz.
   - Muhasebeci gizliliği (`#A3F91C`) korunur.

---

## 2. Oluşturulacak ve Güncellenecek Dosyalar

### A. Modül Kaydı (`apps/swansport_console/lib/app/modules/`)
1. **`console_module.dart`**:
   `ConsoleAudienceAccess` genişletmesi güncellenir:
   ```dart
   ConsoleAudience.federation =>
       isFederationPresident ||
       isRefereeCommitteeMember ||
       isDisciplinaryBoardMember ||
       canPublishFederationResults ||
       federationRoles.isNotEmpty,
   ```
2. **`module_registry.dart`**:
   `kConsoleModules` listesine 3 yeni modül eklenir:
   * `referee_assignments` (MHK Hakem Atama): `/mhk-atamalar` (Audience: `ConsoleAudience.federation`)
   * `provincial_leagues` (İl Lig & Müsabaka Yönetimi): `/il-ligleri` (Audience: `ConsoleAudience.federation`)
   * `disciplinary_board` (Disiplin Kurulu): `/disiplin-kurulu` (Audience: `ConsoleAudience.federation`)

### B. Yeni Ekranlar (`apps/swansport_console/lib/features/federation/`)

#### 1. `referee_assignments_screen.dart` (MHK Hakem Atama Matrisi)
- **Kitle:** MHK Üyeleri, İl Temsilcisi, Federasyon Başkanı.
- **İçerik:**
  - Sol Taraf / Üst Taraf: Haftanın/Sezonun resmi maçları listesi (`ConsoleTable`).
    - Maç Tarihi, Branş, Tesis/Saha, İl, Ev Sahibi, Deplasman.
    - Atanan Görevliler Rozetleri: Başhakem, Yrd. Hakem 1, Yrd. Hakem 2, Masa Hakemi, Gözlemci.
    - Durum Rozeti: `assigned` (Sarı), `accepted` (Yeşil), `declined` (Kırmızı - Ret gerekçesi tooltip ile görünür).
  - Hakem Atama Modalı / Çekmecesi (`RefereeAssignDialog`):
    - Branşa ve ile göre aktif hakemler listelenir (`referee_profiles`).
    - Hakem klasmanı (Aday, İl, Ulusal) ve son maç dinlenme süresi gösterilir.
    - Görev seçilir (`head_referee`, `table_official`, vb.) ve "Ata" butonuna basılır (`assign_match_official` RPC çağrısı).

#### 2. `provincial_leagues_screen.dart` (Federasyon & İl Lig Yönetimi)
- **Kitle:** Federasyon Başkanı (Tüm İller) & İl Temsilcileri (Kendi İli).
- **İçerik:**
  - İl filtresi (Başkan için tüm iller seçilebilir, İl Temsilcisi için kendi ili kilitlidir).
  - Resmi Lig ve Turnuva Fikstürü (`org_matches`).
  - Maç durumları: `scheduled`, `in_progress`, `played`, `cancelled`.
  - Saha / Tesis Tahsisleri ve saat çakışması kontrolü.

#### 3. `disciplinary_board_screen.dart` (Disiplin Kurulu Sevk ve Ceza Paneli)
- **Kitle:** Disiplin Kurulu Üyeleri & Federasyon Başkanı.
- **İçerik:**
  - Hakemlerin maç raporunda kırmızı kart veya saha olayı bildirip sevk ettiği dosyaların kuyruğu (`WorkQueue` stili).
  - Olay Özeti: Maç, Tarih, İlgili Kulüp, Hakemin Rapor Notu, Sevk Edilen Sporcu / Antrenör.
  - "Ceza Kararı Gir" Aksiyonu:
    - Ceza Türü: Maç Men Cezası (1-10 Maç), Hak Mahrumiyeti (1-12 Ay), İhtar, Para Cezası.
    - Gerekçe Metni.
    - Karar onaylandığında sporcunun statüsü güncellenir (`suspended`); sonraki maç esamelerinde otomatik kilitlenir.

---

## 3. Test ve Doğrulama Adımları

1. Konsol testleri: `swansport_console/test/` testleri kırılmamalı (40+ test sabit kalmalı).
2. `python tools/check_faq.py` ve `python tools/check_push_routes.py` (Yeşil kalmalı).
3. `git diff --check` temiz olmalı.
