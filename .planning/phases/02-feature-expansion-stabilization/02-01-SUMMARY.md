---
phase: 02-feature-expansion-stabilization
plan: 01
status: complete
completed: 2026-10-05
requirements:
  - D-01
  - D-02
---

# Phase 02 Plan 01 Summary: SwanTopBar & InboxActions Core Shell Refactoring

Instagram esintili minimalist üst bar (`SwanTopBar`), saf el yazısı "swanspor" logotype'ı ve çerçevesiz 2 ikonlu `InboxActions` mimarisi başarıyla kuruldu.

## Deliverables & Key Changes
1. **`apps/swansport_app/lib/app/widgets/stitch_components.dart`**:
   - `StitchTopBar` 48px sabit yükseklik (`PreferredSizeWidget`) ve `SwanTopBar` aliası ile güncellendi.
   - `isBrand: true` durumunda saf `Text('swanspor', style: SwanType.wordmark(c.ink))` (Caveat script fontu) render ediliyor; bolt ikonu ve gradient rozetleri kaldırıldı.
   - `isBrand: false` durumunda `Icons.arrow_back_ios_new_rounded` (18px) geri butonu, `SwanType.h3` başlık ve ince `c.line` alt kenarlık sağlandı.
2. **`apps/swansport_app/lib/app/widgets/inbox_actions.dart`**:
   - `InboxIconButton` 40x40 kutulu/kenarlıklı yapıdan arındırıldı; 44x44 dokunma alanına sahip çerçevesiz minimalist ikonlara dönüştürüldü (`Icons.favorite_border_rounded` ve `Icons.send_outlined`).
3. **`apps/swansport_app/lib/features/social/presentation/feed_screen.dart`**:
   - Üst bardaki mükerrer `+` butonu kaldırıldı.
   - Yerel kopya header widget'ları temizlendi, doğrudan `const SwanTopBar(isBrand: true, actions: [InboxActions()])` bağlandı.
4. **`apps/swansport_app/lib/features/home/presentation/screens/home_command_center_screen.dart`**:
   - Sol üstteki `_Crest` arması ve yapay rol etiketleri kaldırıldı; sol başta el yazısı "swanspor" ve sağda `InboxActions()` hizalandı.
5. **Testler**:
   - `apps/swansport_app/test/widgets/swan_top_bar_test.dart` (5/5 geçti).
   - `apps/swansport_app/test/widgets/inbox_actions_test.dart` (7/7 geçti).
   - `apps/swansport_app/test/navigation_test.dart` (5/5 geçti).

## Verification
- Widget testleri yeşil.
- `flutter analyze apps/swansport_app` temiz.
- Konsol izolasyonu ve 5'li `SwanBottomNav` korundu.
