import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App ve Pro'nun ortak yedi adımlı tipografi ölçeği.
abstract final class SwanProductType {
  static TextStyle _sora(double size, FontWeight weight, Color color) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.6,
        height: 1.12,
      );

  static TextStyle _jakarta(
    double size,
    FontWeight weight,
    Color color, {
    double height = 1.4,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle wordmark(Color color) =>
      _sora(28, FontWeight.w800, color).copyWith(letterSpacing: -0.5);

  static TextStyle navigationWordmark(Color color) =>
      h2(color).copyWith(fontWeight: FontWeight.w600);

  static TextStyle display(Color color) => _sora(32, FontWeight.w800, color);

  static TextStyle stopwatch(Color color) => display(color).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle h1(Color color) => _sora(28, FontWeight.w800, color);
  static TextStyle h2(Color color) => _sora(22, FontWeight.w700, color);
  static TextStyle h3(Color color) => _sora(18, FontWeight.w700, color);

  static TextStyle body(
    Color color, {
    FontWeight weight = FontWeight.w500,
  }) =>
      _jakarta(16, weight, color);

  static TextStyle bodySm(
    Color color, {
    FontWeight weight = FontWeight.w500,
  }) =>
      _jakarta(14, weight, color);

  static TextStyle caption(
    Color color, {
    FontWeight weight = FontWeight.w600,
  }) =>
      _jakarta(12, weight, color, height: 1.3);
}
