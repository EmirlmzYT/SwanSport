import 'package:flutter/material.dart';

/// Semantic colors used by shared professional-operation screens.
///
/// Hosts map their own design tokens to these meanings. Shared features never
/// infer authorization from presentation values.
final class ProFeatureThemeData {
  const ProFeatureThemeData({
    required this.background,
    required this.surface,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.danger,
    required this.warning,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color line;
  final Color ink;
  final Color inkMuted;
  final Color accent;
  final Color danger;
  final Color warning;
  final Color success;

  static const light = ProFeatureThemeData(
    background: Color(0xFFF6F8FB),
    surface: Color(0xFFFFFFFF),
    line: Color(0xFFE1E6ED),
    ink: Color(0xFF131D2E),
    inkMuted: Color(0xFF667085),
    accent: Color(0xFF008C87),
    danger: Color(0xFFD92D20),
    warning: Color(0xFFB54708),
    success: Color(0xFF027A48),
  );

  static const dark = ProFeatureThemeData(
    background: Color(0xFF101828),
    surface: Color(0xFF1D2939),
    line: Color(0xFF344054),
    ink: Color(0xFFF2F4F7),
    inkMuted: Color(0xFF98A2B3),
    accent: Color(0xFF4CC9C0),
    danger: Color(0xFFF97066),
    warning: Color(0xFFFDB022),
    success: Color(0xFF32D583),
  );
}
