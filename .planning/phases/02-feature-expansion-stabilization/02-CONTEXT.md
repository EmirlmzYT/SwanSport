# Phase 2: Feature Expansion & Stabilization - Context

**Gathered:** 2026-10-05
**Status:** Ready for planning

<domain>
## Phase Boundary

SwanSport mobil ve web uygulamasında (`apps/swansport_app`) görsel bütünlük, tutarlı ekran kabuğu ve Instagram tarzı minimalist header mimarisinin uygulanması. Ekranların birbirinden kopuk görünmesini engelleyen tek tip `SwanTopBar` / `SwanScaffold`, saf script "swanspor" logotype'ı, standart 16px yatay padding, ince kenarlıklar ve rafine kart/liste dikey akışının tüm ana ve alt ekranlara yayılması.

</domain>

<decisions>
## Implementation Decisions

### Header & Wordmark
- **D-01:** Ana sayfa sol üstünde arma, rozet, ekstra kutu ve kalabalık alt başlıklar kaldırılacak; doğrudan ve saf el yazısı script fontuyla (`SwanType.wordmark` - Caveat) "swanspor" marka logotype'ı yer alacak. Sıfır görsel kirlilik. — **Reversibility:** reversible — [Görsel sunum katmanı değişikliği]
- **D-02:** Sağ üstte kutusuz, çerçevesiz, minimalist 2 ikon yer alacak: **Hareketler/Bildirimler** (`Icons.favorite_border_rounded` veya zil) ve **Mesajlar/DM** (`Icons.send_outlined`). Alt gezinme çubuğunda (`SwanBottomNav`) merkezde zaten `+` (Oluştur) butonu olduğu için üst bardaki mükerrer oluştur butonu kaldırılacak. — **Reversibility:** reversible — [Header eylem butonları düzenlemesi]

### Screen Shell & Page Headers
- **D-03:** Tüm uygulamada tek tip standart ekran kabuğu (`SwanTopBar` / `SwanScaffold`) standardı uygulanacak. — **Reversibility:** costly — [Tüm 29 ekranın üst bar ve iskelet yapısını etkiler]
  - Ana sekmelerde: 48px sabit minimalist yükseklik, sol başta başlık/wordmark, sağda ilgili eylemler.
  - Detay ve alt sayfalarda: Sade ince geri butonu (`Icons.arrow_back_ios_new`), `SwanType.h3` sayfa başlığı ve varsa en fazla 1 eylem.
  - Kenar boşluğu standardı: Tüm sayfalarda standart 16px (`SwanSpace.lg`) yatay boşluk; ekranlara göre değişen keyfi padding'ler kaldırılacak.

### Visual Language & Card/List Consistency
- **D-04:** Instagram / Modern Flat & Subtle Border görsel dili standardı: Ağır, yapay renk gradyanları ve parlak kutu gölgeleri yerine; hafif yüzey rengi (`c.surface`), ince zarif sınır çizgisi (`c.line.withValues(alpha: .5)`), standart 14px köşe yuvarlaklığı ve temiz dikey akış. — **Reversibility:** costly — [Tüm ekranlardaki kart ve liste bileşenlerinin görsel stilini belirler]

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Rules & Design Invariants
- `AGENTS.md` — Tasarım jetonları (`SwanType`, `SwanPalette`, `SwanShape`), gezinme (`SwanBottomNav`), gelen kutusu eylemleri (`inbox_actions.dart`) ve mimari invariantlar
- `.planning/codebase/STRUCTURE.md` — Dizin düzeni ve ekran yerleşimleri
- `.planning/codebase/CONVENTIONS.md` — Kodlama ve tasarım standartları

### Core UI Assets
- `apps/swansport_app/lib/app/design/swan_type.dart` — `SwanType.wordmark` (Caveat script fontu) ve 7 adımlı tipografi ölçeği
- `apps/swansport_app/lib/app/design/swan_palette.dart` — `SwanPalette.light` ve `SwanPalette.dark` renk jetonları
- `apps/swansport_app/lib/app/widgets/stitch_components.dart` — `StitchTopBar` ve ortak bileşenler
- `apps/swansport_app/lib/app/widgets/inbox_actions.dart` — Bildirim ve mesaj rozet/eylem sözleşmesi
- `apps/swansport_app/lib/app/widgets/swan_bottom_nav.dart` — 5 sekmeli ana gezinme çubuğu

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SwanType.wordmark(Color c)`: Hazır GoogleFonts.caveat script fontu. Ana sayfa header'ında "swanspor" başlığı için doğrudan kullanılabilir.
- `StitchTopBar`: Mevcut üst bar yapısı refactor edilerek tüm ekranlarda ortak `SwanTopBar` haline dönüştürülebilir.
- `InboxActions`: Bildirim ve mesaj sayaçlarını doğru şekilde yöneten bağımsız eylem widget'ı.

### Established Patterns
- `c = context.swan` veya `isDark ? SwanPalette.dark : SwanPalette.light` ile açık/koyu tema okuma. Koyu temada saf siyah yok (navy/charcoal).
- Sayfalar `ConstrainedBox(constraints: BoxConstraints(maxWidth: 620))` ile responsive ortalanıyor.

### Integration Points
- `apps/swansport_app/lib/features/home/presentation/screens/home_command_center_screen.dart` ve `feed_screen.dart` (Ana sayfa / akış header'ı)
- `apps/swansport_app/lib/app/widgets/stitch_components.dart` (Ortak header ve bileşen kütüphanesi)
- 29 feature ekranındaki başlık, padding ve scaffold iskeletleri

</code_context>

<specifics>
## Specific Ideas

- Instagram tarzı saf, ferah ve modern estetik: Sol üstte el yazısı "swanspor" başlığı, sağda temiz 2 ikon.
- Farklı ekranlardaki kopukluk ve uyumsuzlukların giderilerek tüm uygulamanın tek bir tasarımcının elinden çıkmış gibi hissedilmesi.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-Feature Expansion & Stabilization*
*Context gathered: 2026-10-05*
