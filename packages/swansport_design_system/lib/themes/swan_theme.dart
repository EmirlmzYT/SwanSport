import 'package:flutter/material.dart';
import '../foundations/colors/swan_colors.dart';

class SwanTheme {
  const SwanTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SwanColors.background,
      colorScheme: const ColorScheme.light(
        primary: SwanColors.primary,
        onPrimary: Colors.white,
        primaryContainer: SwanColors.primaryContainer,
        onPrimaryContainer: SwanColors.primary,
        secondary: SwanColors.secondary,
        surface: SwanColors.surface,
        onSurface: SwanColors.textPrimary,
        surfaceContainerHighest: SwanColors.surfaceVariant,
        outline: SwanColors.outline,
        error: SwanColors.error,
      ),
      cardTheme: CardThemeData(
        color: SwanColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SwanColors.outline),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SwanColors.surface,
        foregroundColor: SwanColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SwanColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: SwanColors.darkPrimary,
        onPrimary: Colors.black,
        primaryContainer: Color(0xFF123736),
        onPrimaryContainer: SwanColors.darkPrimary,
        surface: SwanColors.darkSurface,
        onSurface: SwanColors.darkText,
        surfaceContainerHighest: SwanColors.darkSurfaceVariant,
        outline: Color(0xFF2E3440),
        error: SwanColors.error,
      ),
      cardTheme: CardThemeData(
        color: SwanColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E3440)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SwanColors.darkSurface,
        foregroundColor: SwanColors.darkText,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
