import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

class ProTheme {
  const ProTheme._();

  static ThemeData dark() {
    final base = SwanTheme.dark();
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B132B),
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF0EA5E9),
        surface: const Color(0xFF1C2541),
        surfaceContainerHighest: const Color(0xFF283655),
        outline: const Color(0xFF3A4B75),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1C2541),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C2541),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF3A4B75)),
        ),
      ),
    );
  }
}
