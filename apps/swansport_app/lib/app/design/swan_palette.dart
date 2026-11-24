import 'package:flutter/material.dart';
import 'package:swansport_product_ui/swansport_product_ui.dart';

/// SwanSport mobil renk jetonları.
///
/// **Neden konsolun paketinde değil:** `swansport_design_system` paketini
/// masaüstü konsolu da kullanıyor. Konsol bir yönetim aracı; buradaki
/// mobil-sosyal görsel dili oraya taşımak konsolu bozardı. Brief de yalnızca
/// mobil tarafı istiyor.
///
/// **İki palet vardı, bu onları tekleştiriyor.** Tasarım sistemi
/// `darkSurface = 0xFF171A1F` diyordu ama ekranlar 196 yerde `0xFF131D2E`
/// kullanıyordu. Görsel olarak oturmuş olan ekranlarınkiydi; kazanan o.
///
/// **Teal kuralı:** `accent` yalnızca önemli aksiyonları ve aktif durumları
/// vurgular. Dekoratif teal için jeton yok — bilerek. Brief: *"Teal yalnızca
/// önemli aksiyonları ve aktif durumları vurgulamalı."*
class SwanPalette {
  const SwanPalette._({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.accentSoft,
    required this.accentFill,
    required this.successFill,
    required this.success,
    required this.warning,
    required this.danger,
    required this.isDark,
  });

  /// Sayfa zemini.
  final Color bg;

  /// Yükseltilmiş yüzey (satır, sayfa üstü blok).
  final Color surface;

  /// İkincil yüzey — ayırıcı yerine zemin farkı için.
  final Color surfaceAlt;

  /// İnce ayırıcı. Brief "çok az border" diyor: `surfaceAlt` ile birlikte
  /// kullanma, biri yeter.
  final Color line;

  /// Ana metin.
  final Color ink;

  /// İkincil metin, meta, zaman.
  ///
  /// Açık temada `0xFF6B7280` idi ve zemine karşı tam **4.50:1** veriyordu —
  /// eşiğin üstünde ama bir yuvarlama kadar uzağında. Bir tık koyulaştırıldı;
  /// zaman ve alt satır metinleri uygulamanın her yerinde.
  final Color inkMuted;

  /// Marka rengi — yalnızca birincil aksiyon ve aktif durum.
  final Color accent;

  /// Aksiyonun soluk zemini (seçili sekme arkası, ikon kutusu).
  final Color accentSoft;

  /// **Dolu düğme zemini** — üstünde beyaz metin durur.
  ///
  /// `accent`'ten ayrı, çünkü ikisi çelişiyor: `accent` koyu yüzeyde
  /// *okunacak* bir metin rengi (açık olmalı), bu ise *üstünde beyaz metin
  /// okunacak* bir zemin (koyu olmalı). Koyu temada tek renk ikisini birden
  /// yapamıyor — beyaz/parlak teal kontrastı 2.27:1 çıkıyordu, eşik 3:1.
  /// `swan_contrast_test.dart` bunu yakaladı.
  final Color accentFill;

  /// Dolu aksiyon zemininde kontrastlı metin/ikon.
  Color get onAccent => light.surface;

  /// Koyu temada gölge yerine yüzey hiyerarşisi kullanılır.
  Color get shadow =>
      isDark ? bg.withValues(alpha: 0) : light.ink.withValues(alpha: .06);

  /// Onay düğmesi zemini — üstünde beyaz metin durur.
  ///
  /// `success` ikon ve etiket rengi; bu onun koyu karşılığı. Beyaz metin
  /// `success` üstünde 2.54:1 kalıyordu.
  final Color successFill;

  /// Anlam renkleri.
  ///
  /// Değerler ekranların gerçekte kullandığından alındı, uydurulmadı:
  /// `danger` 140 yerde, `warning` 66, `success` 41 kez geçiyordu. İlk
  /// yazdığımda kendi değerlerimi koymuştum ve tam da eleştirdiğim hataya
  /// düşmüştüm — eski tasarım sistemi de böyle kaymıştı.
  final Color success;
  final Color warning;
  final Color danger;

  final bool isDark;

  /// Açık tema.
  static const light = SwanPalette._(
    bg: SwanProductColors.lightBackground,
    surface: SwanProductColors.lightSurface,
    surfaceAlt: SwanProductColors.lightSurfaceAlt,
    line: SwanProductColors.lightLine,
    ink: SwanProductColors.lightInk,
    inkMuted: SwanProductColors.lightInkMuted,
    accent: SwanProductColors.accent,
    accentSoft: SwanProductColors.accentSoft,
    // Caption boyutundaki beyaz etiketlerde de AA kontrastı (5.39:1).
    accentFill: SwanProductColors.accentFill,
    successFill: SwanProductColors.successFill,
    success: SwanProductColors.success,
    warning: SwanProductColors.warning,
    danger: SwanProductColors.danger,
    isDark: false,
  );

  /// Koyu tema.
  ///
  /// Brief: *"saf siyah kullanma, çok koyu navy/charcoal"*. `bg` gerçekten
  /// lacivere çalan bir koyu — `#000000` bu dosyada hiç geçmiyor.
  static const dark = SwanPalette._(
    bg: SwanProductColors.darkBackground,
    surface: SwanProductColors.darkSurface,
    surfaceAlt: SwanProductColors.darkSurfaceAlt,
    line: SwanProductColors.darkLine,
    ink: SwanProductColors.darkInk,
    inkMuted: SwanProductColors.darkInkMuted,
    accent: SwanProductColors.darkAccent,
    accentSoft: SwanProductColors.darkAccentSoft,
    accentFill: SwanProductColors.accentFill,
    successFill: SwanProductColors.successFill,
    success: SwanProductColors.success,
    warning: SwanProductColors.warning,
    danger: SwanProductColors.danger,
    isDark: true,
  );

  static SwanPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// `SwanPalette.of(context)` kısayolu.
///
/// Ekranların başındaki `final isDark = ...; final bg = isDark ? ... : ...;`
/// altı satırlık tekrarının yerine geçiyor.
extension SwanPaletteContext on BuildContext {
  SwanPalette get swan => SwanPalette.of(this);
}
