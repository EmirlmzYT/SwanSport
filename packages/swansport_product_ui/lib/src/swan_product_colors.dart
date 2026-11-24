import 'package:flutter/material.dart';

/// SwanSport App ve SwanSport Pro'nun ortak ürün renkleri.
///
/// Masaüstü yönetim konsolu bilerek bu paketi kullanmaz. Böylece sosyal mobil
/// dil iki son kullanıcı uygulamasında ortak kalırken konsolun operasyonel
/// tasarım sistemi etkilenmez.
abstract final class SwanProductColors {
  static const lightBackground = Color(0xFFF4F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF1F5F8);
  static const lightLine = Color(0xFFEAEEF3);
  static const lightInk = Color(0xFF111827);
  static const lightInkMuted = Color(0xFF636B77);

  static const darkBackground = Color(0xFF0A111E);
  static const darkSurface = Color(0xFF1B273A);
  static const darkSurfaceAlt = Color(0xFF1A2537);
  static const darkLine = Color(0xFF233149);
  static const darkInk = Color(0xFFFFFFFF);
  static const darkInkMuted = Color(0xFF8A97AC);

  static const accent = Color(0xFF008C95);
  static const accentSoft = Color(0x1A008C95);
  static const accentFill = Color(0xFF00767E);
  static const darkAccent = Color(0xFF2FBFB6);
  static const darkAccentSoft = Color(0x1A2FBFB6);

  static const successFill = Color(0xFF047857);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFD9860B);
  static const danger = Color(0xFFF43F5E);
}
