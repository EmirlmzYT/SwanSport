import 'package:flutter/material.dart';
import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Mobil uygulamanın Stitch "Calm Athletic Modernism" teması.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _theme(SwanPalette.light);
  static ThemeData dark() => _theme(SwanPalette.dark);

  static ThemeData _theme(SwanPalette c) {
    final scheme = ColorScheme(
      brightness: c.isDark ? Brightness.dark : Brightness.light,
      primary: c.accentFill,
      onPrimary: Colors.white,
      secondary: c.accent,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.ink,
      outline: c.line,
      surfaceContainerHighest: c.surfaceAlt,
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SwanRadius.sm),
      borderSide: BorderSide.none,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.line,
      splashColor: c.accentSoft,
      highlightColor: c.accentSoft,
      textTheme: TextTheme(
        displayLarge: SwanType.display(c.ink),
        headlineLarge: SwanType.h1(c.ink),
        headlineMedium: SwanType.h2(c.ink),
        titleLarge: SwanType.h3(c.ink),
        bodyLarge: SwanType.body(c.ink),
        bodyMedium: SwanType.bodySm(c.ink),
        bodySmall: SwanType.caption(c.inkMuted),
        labelLarge: SwanType.bodySm(c.ink, w: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: SwanType.h2(c.ink),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanRadius.md),
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SwanSpace.lg,
          vertical: 14,
        ),
        hintStyle: SwanType.bodySm(c.inkMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          backgroundColor: c.accentFill,
          foregroundColor: Colors.white,
          textStyle: SwanType.bodySm(Colors.white, w: FontWeight.w700),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: c.ink,
          side: BorderSide(color: c.line, width: 1.5),
          textStyle: SwanType.bodySm(c.ink, w: FontWeight.w700),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: c.accent,
          textStyle: SwanType.bodySm(c.accent, w: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceAlt,
        selectedColor: c.accentFill,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanRadius.sm),
        ),
        labelStyle: SwanType.bodySm(c.inkMuted),
        secondaryLabelStyle: SwanType.bodySm(Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SwanRadius.lg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanRadius.lg),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accentFill,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanRadius.lg),
        ),
      ),
    );
  }
}
