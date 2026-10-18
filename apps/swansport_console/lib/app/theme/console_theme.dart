import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

final consoleThemeModeProvider =
    StateProvider<ThemeMode>((ref) => ThemeMode.dark);

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
  static const double rowHeight = 42;
  static const double headerHeight = 38;

  /// Kabuk ölçüleri.
  static const double sidebarWidth = 264;
  static const double sidebarCollapsedWidth = 68;
  static const double topBarHeight = 60;

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

  static const double radius = 12;
  static const double loginCardWidth = 430;
  static const double dashboardKpiMinWidth = 210;
  static const double dashboardQueueMinWidth = 420;
  static const double dashboardActionMinWidth = 280;
  static const double dashboardKpiHeight = 250;
  static const double logoPreviewSize = 80;
  static const double brandMarkSize = 22;
  static const double loginBrandMarkSize = 48;
}

class ConsoleTheme {
  const ConsoleTheme._();

  // Console-owned athletic dark palette aligned with swansport.com.tr;
  // widgets consume ThemeData, not hex.
  static const Color commandBackground = Color(0xFF070D19);
  static const Color commandSurface = Color(0xFF0F172A);
  static const Color commandSurfaceAlt = Color(0xFF17233B);
  static const Color commandAccent = Color(0xFF00C7B1);
  static const Color commandSecondary = Color(0xFFF59E0B);
  static const Color commandOutline = Color(0xFF22324F);
  static const Color commandMuted = Color(0xFF94A3B8);

  static ThemeData light() => _build(
        brightness: Brightness.light,
        background: const Color(0xFFF4F7FB),
        surface: SwanColors.surface,
        surfaceAlt: const Color(0xFFEEF3F9),
        outline: const Color(0xFFD8E2EE),
        ink: SwanColors.textPrimary,
        inkMuted: SwanColors.textSecondary,
        primary: SwanColors.primary,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        background: commandBackground,
        surface: commandSurface,
        surfaceAlt: commandSurfaceAlt,
        outline: commandOutline,
        ink: SwanColors.darkText,
        inkMuted: commandMuted,
        primary: commandAccent,
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
    final isDark = brightness == Brightness.dark;
    // Rakamlar tabular: tabloda alt alta gelen sayılar kaymasın.
    final body = GoogleFonts.interTextTheme().apply(
      bodyColor: ink,
      displayColor: ink,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: SwanColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: commandSecondary,
      tertiary: commandSecondary,
      surface: surface,
      surfaceContainerHighest: surfaceAlt,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      outline: outline,
      outlineVariant: outline.withValues(alpha: isDark ? 0.75 : 0.85),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      textTheme: body.copyWith(
        headlineMedium: GoogleFonts.inter(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: ink,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: ink,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: ink,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: ink,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyMedium: GoogleFonts.inter(fontSize: 13.5, color: ink),
        bodySmall: GoogleFonts.inter(fontSize: 12.5, color: inkMuted),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .65,
          color: inkMuted,
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          side: BorderSide(color: outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius + 4),
          side: BorderSide(color: outline),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          side: BorderSide(color: outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: inkMuted,
        dividerColor: outline,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.md + 2,
          vertical: ConsoleDensity.sm + 4,
        ),
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? commandAccent : SwanColors.primary,
          foregroundColor: isDark ? const Color(0xFF041318) : Colors.white,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: ConsoleDensity.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
