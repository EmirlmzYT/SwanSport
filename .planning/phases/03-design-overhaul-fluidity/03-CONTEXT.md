# Phase 3: Comprehensive Design Polish & Fluidity - Context

**Gathered:** 2026-10-05
**Actor:** Codex Writer (UI Execution) & AGY Reviewer
**Status:** Ready for planning

<domain>
## Phase Boundary

SwanSport mobil ve web uygulamasında (pps/swansport_app) kullanıcının talebi doğrultusunda tüm sayfaların görsel tasarımının elden geçirilmesi, görsel parçalanmaların giderilmesi ve uygulamanın en yüksek seviyede akıcı, pürüzsüz ve premium (iOS/Instagram spor platformu kalitesinde) hissettirmesi.

Codex Writer'ın adım adım uygulayacağı bu faz; yükleme durumlarından kaydırma fiziğine, kart derinliğinden mikro-etkileşimlere kadar tüm ana sekme ve alt ekranları kapsar. Konsol (pps/swansport_console) kesinlikle bu fazın kapsamı dışındadır.

</domain>

<decisions>
## Implementation Decisions for Codex Writer

### Fluidity & Perceived Performance
- **D-01: Akıcı Shimmer İskelet Yükleme Durumları (Skeleton Loading)**
  - Ekranlarda beklemeyi uzatan, yapay duran dönen çemberler (CircularProgressIndicator) kaldırılacak.
  - Veri yüklenirken içeriğin gerçek geometrisini taklit eden yumuşak parıltılı SwanListSkeleton, SwanShimmer ve kart iskeletleri (premiumLoading()) kullanılacak. Sayfa yüklendiğinde içerik sıçramadan pürüzsüzce oturacak.
  - **Reversibility:** costly — [Tüm ekranlardaki asenkron when(loading: ...) dallarını standartlaştırır]

- **D-02: Pürüzsüz Kaydırma Fiziği (BouncingScrollPhysics)**
  - Tüm dikey ve yatay kaydırılabilir listelerde (CustomScrollView, ListView, yatay filtre şeritleri) iOS benzeri akıcı BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()) uygulanacak.
  - Android ve Web üzerinde sert duvara çarpma hissi yerine elastik, akıcı sınır geçişi sağlanacak.
  - **Reversibility:** reversible — [ScrollPhysics parametresi standardizasyonu]

### Micro-Interactions & Tap Feedback
- **D-03: Dokunma Geri Bildirimi ve Yumuşak Mikro-Animasyonlar**
  - Kartlarda, butonlarda ve filtre haplarında (StitchFilterPill, SwanChip, _FeedPill) kaba jest yutulmaları engellenecek.
  - InkWell dokunma dalgası veya AnimatedScale (örneğin beğeni pop animasyonu 1.0 -> 1.25 -> 1.0) ile her dokunuşta canlı ve tatmin edici bir dokunsal/görsel tepki verilecek.
  - **Reversibility:** reversible — [Widget etkileşim katmanı]

### Screen-by-Screen Aesthetic Elevation
- **D-04: Ana Sekmelerin Tamamlanması (Wave 1)**
  - **Feed (eed_screen.dart):** Pinned üst bar, hafif yatay aktivite/görev şeridi, akıcı post kartları ve Instagram benzeri temiz etkileşim satırı.
  - **Keşfet (explore_screen.dart):** İnteraktif arama kutusu (StitchSearchBar), akıcı yatay kategori hapları, modern spor tesisi/kort kartları.
  - **Mesajlar (messages_screen.dart):** SwanSegmentedTabs ile Direkt/Topluluklar geçişi, aktif avatarlar, unread badge ve sohbet baloncukları estetiği.
  - **Profil (profile_screen.dart):** Modern profil başlığı, takipçi/kulüp istatistik kutucukları, pürüzsüz sekme geçişi.
  - **Arama (search_screen.dart):** Akıcı klavye yönetimi, temiz sonuç kartları.
  - **Reversibility:** costly — [Ana gezinme yüzeyleri]

- **D-05: Alt Ekranlar, Tesisler ve Yönetim Sayfaları (Wave 2)**
  - **Sahalar & Partner Bul (enues_screen.dart, ind_partner_screen.dart):** Zemin tipi rozetleri (Toprak, Sert, Çim), mesafe bilgisi, filtre sheet'leri.
  - **Sporcu & Kadro (thlete_workspace_screen.dart, 	eam_roster_screen.dart):** Kadro listesi, sporcu kartları, devam durumu çipleri.
  - **Bildirimler (
otifications_screen.dart):** Gruplanmış liste (Bugün, Bu Hafta), okunmamış durum vurgusu.
  - **Finans & Aidat (inance_screen.dart, my_fees_screen.dart):** Modern bakiye kartı, aidat durum çipleri (success, warning, danger).
  - **Takvim (schedule_calendar_screen.dart):** Gün/hafta seçici, etkinlik kartları.
  - **Ayarlar & Gizlilik (club_settings_screen.dart, privacy_screen.dart):** iOS stili gruplanmış yuvarlak liste satırları.
  - **Reversibility:** costly — [Alt modül ekranları]

- **D-06: Modal Bottom Sheet ve İletişim Kutuları**
  - Tüm modal pencerelerde (create_sheet.dart, comments_sheet.dart, 
eport_sheet.dart) standart 22px yuvarlatılmış tepe (SwanRadius.lg), tutma/sürükleme çubuğu ve akıcı yaylı kapanma hissiyatı.
  - **Reversibility:** reversible — [Sheet dekorasyon standardı]

</decisions>

<canonical_refs>
## Canonical References

**Codex Writer ve Reviewer ajanları aşağıdaki değişmez kurallara uymak ZORUNDADIR:**

### Depo Kılavuzları ve Değişmezler
- AGENTS.md — En yetkili proje kılavuzu.
  - swansport_design_system mobilde kullanılmaz (konsola aittir).
  - Tipografi 7 adımdır (SwanType). Ham sayı yazılmaz.
  - Koyu temada saf siyah (#000000) kullanılmaz; navy/charcoal (SwanPalette.dark).
  - Gezinme 5 öğelidir (SwanBottomNav).
  - Birleşen sayfaların rota sözleşmeleri ve _marks yoklama durumu korunur.
- .ai-team/TEAM_BOARD.md — Writer devir ve kayıt defteri.
- pps/swansport_app/lib/app/design/ — swan_type.dart, swan_palette.dart, swan_shape.dart.
- pps/swansport_app/lib/app/widgets/ — stitch_components.dart, swan_skeleton.dart, swan_tabs.dart, inbox_actions.dart.

</canonical_refs>

<code_context>
## Codebase Invariants & Test Gates

1. **Test Güvenceleri:**
   - 	est/widgets/swan_top_bar_test.dart
   - 	est/widgets/inbox_actions_test.dart
   - 	est/navigation_test.dart
   - 	est/merged_routes_test.dart
   - 	est/athlete_detail_navigation_test.dart
   - 	est/athlete_detail_screen_test.dart
   Tüm testler yeşil kalmak zorundadır.

2. **Konsol Bağımsızlığı:**
   - pps/swansport_console paketine dokunulmaz.
   - packages/swansport_design_system masaüstü konsolu tarafından tüketildiği için mobil değişiklikler bu pakete sızdırılamaz.
