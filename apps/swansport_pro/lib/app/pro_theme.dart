import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class ProTheme {
  const ProTheme._();

  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF0E1B2C);
  static const surfaceRaised = Color(0xFF14243A);
  static const line = Color(0xFF263A55);
  static const primary = Color(0xFF2DD4BF);
  static const secondary = Color(0xFF38BDF8);
  static const ink = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);

  static ThemeData dark() {
    final base = SwanTheme.dark();
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: primary,
        onPrimary: const Color(0xFF03201D),
        secondary: secondary,
        surface: surface,
        surfaceContainer: surfaceRaised,
        surfaceContainerHighest: const Color(0xFF1A2D46),
        outline: line,
        onSurface: ink,
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
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF03201D),
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }
}
