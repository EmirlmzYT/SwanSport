---
phase: 02-feature-expansion-stabilization
plan: 02
status: complete
completed: 2026-10-05
requirements:
  - D-03
  - D-04
---

# Phase 02 Plan 02 Summary: Screen Shell, 16px Padding & Detail Header Standardization

Tüm ana ve alt ekranlarda sayfa kabuğu (`SwanTopBar`), 16px yatay kenar boşlukları (`SwanSpace.lg`), flat border kart estetiği (`SwanRadius.md`, `c.surface`, `c.line.withValues(alpha: .5)`) ve alt ekran geri butonları başarıyla standardize edildi.

## Deliverables & Key Changes
1. **`apps/swansport_app/lib/app/widgets/stitch_components.dart`**:
   - `SwanTopBar` geri butonuna `Tooltip(message: 'Geri dön')` eklendi, erişilebilirlik ve navigasyon test uyumu sağlandı.
2. **`apps/swansport_app/lib/features/network/presentation/explore_screen.dart`**:
   - `SwanTopBar(title: 'Keşfet', showBack: false)` entegre edildi.
   - `_QuickExplore` modül kartları 16px (`SwanSpace.lg`) ve 14px radius (`SwanRadius.md`) flat kart stiline çekildi.
3. **`apps/swansport_app/lib/features/social/presentation/profile_screen.dart`**:
   - 20px padding'ler standart 16px'e (`SwanSpace.lg`) dönüştürüldü.
   - Kartlar ve aksiyon butonları 14px radius ve ince sınır çizgisi ile hizalandı.
4. **`apps/swansport_app/lib/features/social/presentation/messages_screen.dart`**:
   - Mesajlar ana ekranı ve `ChatScreen` üst barları `SwanTopBar` standardına kavuşturuldu; liste ve mesaj alanı 16px padding ile hizalandı.
5. **`apps/swansport_app/lib/features/athlete_workspace/presentation/screens/athlete_detail_screen.dart`**:
   - `SwanTopBar(title: 'Sporcu Detayı', showBack: true)` ile standartlaştırıldı.
   - Ham renkler `c.accent`, `c.warning` gibi `SwanPalette` jetonlarına çekildi; kartlar 14px radius ve ince kenarlığa bağlandı.
6. **`apps/swansport_app/lib/features/social/presentation/notifications_screen.dart`**:
   - `SwanTopBar(title: 'Bildirimler', showBack: true)` ve 16px padding standardı uygulandı.
7. **`apps/swansport_app/lib/features/attendance/presentation/screens/live_attendance_screen.dart` & `attendance_history_screen.dart`**:
   - `SwanTopBar` başlık ve geri butonu eklendi, 16px padding uygulandı.
   - AGENTS.md kuralı korundu: `_marks` yoklama durumu korunarak ekranlar birleştirilmedi.
8. **Testler ve Doğrulama**:
   - `navigation_test.dart` (5/5)
   - `merged_routes_test.dart` (4/4)
   - `athlete_detail_navigation_test.dart` (3/3)
   - `athlete_detail_screen_test.dart` (4/4)
   - `flutter analyze apps/swansport_app` 0 error, 0 warning.

## Verification
- Tüm testler yeşil.
- Konsol izolasyonu (0 git diff) ve Melos paket sınırları korundu.
