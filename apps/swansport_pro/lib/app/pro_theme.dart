import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_product_ui/swansport_product_ui.dart';

class ProTheme {
  const ProTheme._();

  static const background = SwanProductColors.lightBackground;
  static const surface = SwanProductColors.lightSurface;
  static const surfaceRaised = SwanProductColors.lightSurfaceAlt;
  static const line = SwanProductColors.lightLine;
  static const primary = SwanProductColors.accentFill;
  static const secondary = SwanProductColors.accent;
  static const success = SwanProductColors.success;
  static const onSuccess = Colors.white;
  static const warning = SwanProductColors.warning;
  static const onWarning = Color(0xFF2A1900);
  static const danger = SwanProductColors.danger;
  static const onDanger = Color(0xFFFFFFFF);
  static const ink = SwanProductColors.lightInk;
  static const muted = SwanProductColors.lightInkMuted;

  static ThemeData light() {
    final base = SwanTheme.light();
    return base.copyWith(
      scaffoldBackgroundColor: background,
      focusColor: primary.withValues(alpha: 0.16),
      hoverColor: primary.withValues(alpha: 0.08),
      highlightColor: primary.withValues(alpha: 0.12),
      splashColor: primary.withValues(alpha: 0.14),
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        surface: surface,
        surfaceContainer: surfaceRaised,
        surfaceContainerHighest: surfaceRaised,
        outline: line,
        onSurface: ink,
      ),
      textTheme: TextTheme(
        displayLarge: SwanProductType.display(ink),
        headlineLarge: SwanProductType.h1(ink),
        headlineMedium: SwanProductType.h2(ink),
        titleLarge: SwanProductType.h3(ink),
        bodyLarge: SwanProductType.body(ink),
        bodyMedium: SwanProductType.bodySm(ink),
        bodySmall: SwanProductType.caption(muted),
        labelLarge: SwanProductType.bodySm(
          ink,
          weight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanProductRadius.md),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: SwanProductType.bodySm(muted),
        hintStyle: SwanProductType.bodySm(muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SwanProductRadius.md),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SwanProductRadius.md),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SwanProductRadius.md),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanProductRadius.md),
          ),
          textStyle: SwanProductType.bodySm(
            Colors.white,
            weight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanProductRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanProductRadius.md),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanProductRadius.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }

  /// Geçiş döneminde eski test ve çağrıları kırmadan açık ürün temasına taşır.
  @Deprecated('Use ProTheme.light().')
  static ThemeData dark() => light();
}
