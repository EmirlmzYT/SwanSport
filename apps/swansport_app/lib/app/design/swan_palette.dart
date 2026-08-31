import 'package:flutter/material.dart';

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
    bg: Color(0xFFF4F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F5F8),
    line: Color(0xFFEAEEF3),
    ink: Color(0xFF111827),
    inkMuted: Color(0xFF636B77),
    accent: Color(0xFF008C95),
    accentSoft: Color(0x1A008C95),
    accentFill: Color(0xFF008C95),
    successFill: Color(0xFF047857),
    success: Color(0xFF10B981),
    warning: Color(0xFFD9860B),
    danger: Color(0xFFF43F5E),
    isDark: false,
  );

  /// Koyu tema.
  ///
  /// Brief: *"saf siyah kullanma, çok koyu navy/charcoal"*. `bg` gerçekten
  /// lacivere çalan bir koyu — `#000000` bu dosyada hiç geçmiyor.
  static const dark = SwanPalette._(
    bg: Color(0xFF0A111E),
    surface: Color(0xFF131D2E),
    surfaceAlt: Color(0xFF1A2537),
    line: Color(0xFF233149),
    ink: Color(0xFFFFFFFF),
    inkMuted: Color(0xFF8A97AC),
    accent: Color(0xFF2FBFB6),
    accentSoft: Color(0x1A2FBFB6),
    accentFill: Color(0xFF00767E),
    successFill: Color(0xFF047857),
    success: Color(0xFF10B981),
    warning: Color(0xFFD9860B),
    danger: Color(0xFFF43F5E),
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
