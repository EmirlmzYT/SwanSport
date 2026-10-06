# Phase 02: Feature Expansion & Stabilization - Research

**Researched:** 2026-10-05
**Domain:** Flutter UI / Design System / Screen Shell & Header Architecture
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Ana sayfa sol üstünde arma, rozet, ekstra kutu ve kalabalık alt başlıklar kaldırılacak; doğrudan ve saf el yazısı script fontuyla (`SwanType.wordmark` - Caveat) "swanspor" marka logotype'ı yer alacak. Sıfır görsel kirlilik. — **Reversibility:** reversible
- **D-02:** Sağ üstte kutusuz, çerçevesiz, minimalist 2 ikon yer alacak: **Hareketler/Bildirimler** (`Icons.favorite_border_rounded`) ve **Mesajlar/DM** (`Icons.send_outlined`). Alt gezinme çubuğunda (`SwanBottomNav`) merkezde zaten `+` (Oluştur) butonu olduğu için üst bardaki mükerrer oluştur butonu kaldırılacak. — **Reversibility:** reversible
- **D-03:** Tüm uygulamada tek tip standart ekran kabuğu (`SwanTopBar` / `SwanScaffold`) standardı uygulanacak. — **Reversibility:** costly
  - Ana sekmelerde: 48px sabit minimalist yükseklik, sol başta başlık/wordmark, sağda ilgili eylemler.
  - Detay ve alt sayfalarda: Sade ince geri butonu (`Icons.arrow_back_ios_new_rounded`), `SwanType.h3` sayfa başlığı ve varsa en fazla 1 eylem.
  - Kenar boşluğu standardı: Tüm sayfalarda standart 16px (`SwanSpace.lg`) yatay boşluk; ekranlara göre değişen keyfi 20px padding'ler kaldırılacak.
- **D-04:** Instagram / Modern Flat & Subtle Border görsel dili standardı: Ağır, yapay renk gradyanları ve parlak kutu gölgeleri yerine; hafif yüzey rengi (`c.surface`), ince zarif sınır çizgisi (`c.line.withValues(alpha: .5)`), standart 14px köşe yuvarlaklığı (`SwanRadius.md`) ve temiz dikey akış. — **Reversibility:** costly

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<architectural_responsibility_map>
## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Script Wordmark & Top Bar | Mobile/Web Flutter UI (`apps/swansport_app/lib/app/widgets/`) | Design System (`app/design/swan_type.dart`) | Ortak header bileşeni Flutter sunum katmanına aittir. |
| Action Icons & Badges | Flutter Presentation (`inbox_actions.dart`) | Data Access (`unreadNotificationsProvider`, `unreadMessagesProvider`) | Rozet sayıları `swansport_data` sağlayıcılarından okunur, UI sadece gösterir. |
| Screen Padding & Shell | Flutter Screens (`apps/swansport_app/lib/features/`) | Shared Widgets | Tüm feature ekranları standart `SwanTopBar` ve 16px padding sözleşmesine bağlanır. |
| Console Isolation | Desktop Web Console (`apps/swansport_console`) | `packages/swansport_design_system` | Mobil-sosyal tasarım dili masaüstü konsoluna asla taşınmaz. |
</architectural_responsibility_map>

<research_summary>
## Summary

SwanSport mobil ve web uygulamasında (`apps/swansport_app`) 29 özellik ekranı taranmış; tasarım sistemi koruyucusu (`design-system-reviewer`) ve görsel tasarımcı (`visual-designer`) uzmanlarımız tarafından derinlemesine incelenmiştir.

Mevcut durumda ekranlar arasında 3 temel uyumsuzluk tespit edilmiştir:
1. **Header Çelişkisi:** Ana akış (`feed_screen`) şeffaf ikonlar kullanırken, komuta merkezi (`home_command_center_screen`) 40x40 kutulu armalar ve gradientli bolt rozetleri enjekte etmektedir. Üst barda mükerrer `+` butonu bulunurken, alt barda zaten `SwanBottomNav`'ın merkezinde `+` yer almaktadır.
2. **Padding ve Radius Düzensizliği:** Bazı ekranlar 20px (`home`, `profile`), bazıları 16px (`feed`, `explore`) yatay padding kullanmakta; bu durum sekme geçişlerinde 4px sağa-sola sıçramalara yol açmaktadır. Köşe yuvarlaklıkları 12, 13, 16, 18, 22px gibi dağınıktır.
3. **Alt Ekran Geri Butonu Eksikliği:** `StitchTopBar` geri butonu parametresi barındırmadığı için detay sayfalarında gezinme tutarsızlıkları oluşmaktadır.

Çözüm: `SwanType.wordmark` (Caveat script fontu) sol üstte saf marka başlığı olarak kullanılacak; `StitchTopBar` 48px sabit yükseklik, otomatik geri butonu ve 2 minimalist eylem ikonuyla (`favorite_border_rounded` ve `send_outlined`) standart `SwanTopBar` bileşenine dönüştürülecektir. Tüm ekranlar 16px yatay padding ve 14px radius ile hizalanacaktır.
</research_summary>

<technical_findings>
## Technical Findings

### 1. Script Wordmark ("swanspor") İmplementasyonu
- `apps/swansport_app/lib/app/design/swan_type.dart` dosyasında `SwanType.wordmark(Color c)` zaten GoogleFonts.caveat (28px, w700, letterSpacing: -0.8) olarak mevcuttur.
- 48px bar yüksekliğinde Caveat 28px optik olarak ~24px x-height sunar ve dikeyde mükemmel oturur.
- Sol tarafta arma kutusu (`_Crest`), şimşek rozeti (`bolt_rounded`) ve alt metinler ("Yönetici", "Antrenör") tamamen kaldırılarak doğrudan `Text('swanspor', style: SwanType.wordmark(c.ink))` render edilecektir.

### 2. Header Aksiyonları & InboxActions Refactoring
- `inbox_actions.dart` içindeki `InboxIconButton` kutulu/borderlı 40x40 arka plandan arındırılacak; 44x44 dokunma alanına sahip çerçevesiz minimalist ikonlara dönüştürülecektir.
- Sol eylem: `Icons.favorite_border_rounded` (Hareketler/Bildirimler, rozet: `unreadNotificationsProvider`).
- Sağ eylem: `Icons.send_outlined` (Mesajlar/DM, rozet: `unreadMessagesProvider`).
- `feed_screen.dart` içindeki mükerrer `_HeaderIcon`, `_ActivitiesHeaderAction`, `_MessagesHeaderAction` ve `add_box_outlined` (+) kaldırılacaktır.

### 3. Ortak Ekran Kabuğu (`SwanTopBar`) Sözleşmesi
- `stitch_components.dart` içindeki `StitchTopBar` genişletilecek / `SwanTopBar` sözleşmesi kurulacaktır:
  - `isBrand: true` -> Sol başta saf Caveat 'swanspor' + Sağda 2 ikon.
  - `isBrand: false` -> Sol başta `Icons.arrow_back_ios_new_rounded` (eğer `Navigator.canPop` ise) + `SwanType.h3(c.ink)` başlık + Varsa 1 eylem (`trailing`).
  - Yükseklik: Sabit 48px.
  - Zemin: `c.surface.withValues(alpha: c.isDark ? .92 : .98)` + alt ince sınır `c.line.withValues(alpha: .5)`.

### 4. Ekran Boyu Padding ve Kart Standartları
- Tüm ekranlarda `EdgeInsets.fromLTRB(20, ...)` kullanımları `SwanSpace.lg` (16px) standardına çekilecektir.
- Kartlar: `c.surface` zemin, `Border.all(color: c.line.withValues(alpha: .5))` ve `SwanRadius.md` (14px). Ağır gradyanlı kutular (`StitchHeroCard` 82px watermark ikonları) sadeleştirilecektir.
</technical_findings>

<validation_architecture>
## Validation Architecture

### 1. Test Stratejisi & Kapsam
- `apps/swansport_app/test/widgets/inbox_actions_test.dart`: 2-ikonlu yeni minimalist yapının rozet sayımını ve dokunma eylemlerini (Notifications ve Messages rotalarına gidiş) doğrulama.
- `apps/swansport_app/test/widgets/swan_top_bar_test.dart` (Yeni test):
  - Marka modunda (`isBrand: true`) 'swanspor' yazısının ve 2 aksiyonun render edildiğinin, bolt veya crest bulunmadığının doğrulanması.
  - Alt ekran modunda geri butonunun `maybePop` tetiklediğinin ve başlığın gösterildiğinin doğrulanması.
- `apps/swansport_app/test/navigation_test.dart` & `merged_routes_test.dart`: Rota sözleşmelerinin ve derin bağlantıların korunduğunun doğrulanması.

### 2. Statik Analiz & Kod Standartları
- `flutter analyze apps/swansport_app` sıfır hata ile geçmeli.
- `apps/swansport_console` testleri (40 test) etkilenmemeli ve konsol bağımsızlığı korunmalı.
</validation_architecture>
