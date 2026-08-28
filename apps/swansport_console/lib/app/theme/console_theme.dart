import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

/// Konsolun görsel dili.
///
/// Marka rengi ve yüzeyler `SwanColors`'tan gelir — mobil uygulamayla aynı
/// SwanSport'a baktığın belli olsun diye. Ölçekler ise farklıdır: mobilde
/// parmak hedefi 44–48px, burada fare ve klavye var. Satır yüksekliği,
/// boşluk ve yazı boyutu buna göre sıkılaştırıldı; ekrana daha çok satır
/// sığması yönetim işinin tamamı.
class ConsoleDensity {
  const ConsoleDensity._();

  /// Tablo satırı — 200 satırlık bir kadroda fark eden ölçü budur.
  static const double rowHeight = 40;
  static const double headerHeight = 36;

  /// Kabuk ölçüleri.
  static const double sidebarWidth = 260;
  static const double sidebarCollapsedWidth = 64;
  static const double topBarHeight = 56;

  /// Konsolun çalışabildiği en dar ekran.
  ///
  /// 900px, yatay tutulan bir tabletin genişliği. Önce 1024 yazılmıştı ama o
  /// eşik tablet kullanıcısını ortada bırakıyordu: ne konsolu açabiliyor ne
  /// de tarayıcıda mobil uygulamayı kullanabiliyordu. 900'de tablolar hâlâ
  /// okunuyor — yeter ki kenar çubuğu yer kaplamasın (bkz. [autoCollapseWidth]).
  static const double minSupportedWidth = 900;

  /// Bu genişliğin altında kenar çubuğu kendiliğinden daralır.
  ///
  /// Dar ekranda 260px'lik menü, tablonun sütunlarından çalınan yerdir;
  /// simgeler yeterince anlaşılır olduğu için daraltılmış hâli tercih edilir.
  static const double autoCollapseWidth = 1180;

  /// Boşluk ölçeği (4'ün katları).
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double radius = 10;
}

class ConsoleTheme {
  const ConsoleTheme._();

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: SwanColors.background,
        surface: SwanColors.surface,
        surfaceAlt: SwanColors.surfaceVariant,
        outline: SwanColors.outline,
        ink: SwanColors.textPrimary,
        inkMuted: SwanColors.textSecondary,
        primary: SwanColors.primary,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: SwanColors.darkBackground,
        surface: SwanColors.darkSurface,
        surfaceAlt: SwanColors.darkSurfaceVariant,
        outline: const Color(0xFF2A313B),
        ink: SwanColors.darkText,
        inkMuted: const Color(0xFF9AA4B2),
        primary: SwanColors.darkPrimary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color outline,
    required Color ink,
    required Color inkMuted,
    required Color primary,
  }) {
    // Rakamlar tabular: tabloda alt alta gelen sayılar kaymasın.
    final body = GoogleFonts.interTextTheme().apply(
      bodyColor: ink,
      displayColor: ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: SwanColors.primary,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        surface: surface,
        outline: outline,
      ),
      textTheme: body.copyWith(
        titleLarge: GoogleFonts.inter(
            fontSize: 20, fontWeight: FontWeight.w700, color: ink),
        titleMedium: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600, color: ink),
        bodyMedium: GoogleFonts.inter(fontSize: 13.5, color: ink),
        bodySmall: GoogleFonts.inter(fontSize: 12.5, color: inkMuted),
        labelSmall: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: .6,
            color: inkMuted),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: ConsoleDensity.md, vertical: ConsoleDensity.sm + 2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          ),
          textStyle:
              GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
