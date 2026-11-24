import 'package:swansport_product_ui/swansport_product_ui.dart';

/// SwanSport mobil biçim ve boşluk jetonları.
///
/// Brief: *"medium radius, çok az border, çok az shadow"* ve *"Card yerine
/// mümkün olduğunca section / list / inline action / media / sheet kullan."*
///
/// Mevcut hâl tam tersiydi: neredeyse her şey `Border.all(...)` +
/// `borderRadius: 17` içinde bir kutuydu. Bu jetonlar o alışkanlığı
/// kırmak için dar tutuldu — üç radius, beş boşluk, o kadar.
class SwanRadius {
  const SwanRadius._();

  /// 10 — rozet, küçük hap, ikon kutusu.
  static const double sm = SwanProductRadius.sm;

  /// 14 — satır, alan, düğme. Varsayılan bu.
  static const double md = SwanProductRadius.md;

  /// 22 — yalnızca görsel/hero alanları ve bottom sheet.
  ///
  /// Brief "büyük radius yalnızca görsel/hero alanlarında" diyor; normal
  /// içerik için kullanma.
  static const double lg = SwanProductRadius.lg;
}

class SwanSpace {
  const SwanSpace._();

  static const double xs = SwanProductSpace.xs;
  static const double sm = SwanProductSpace.sm;
  static const double md = SwanProductSpace.md;

  /// 16 — ekran kenar boşluğu ve bloklar arası varsayılan.
  static const double lg = SwanProductSpace.lg;

  /// 24 — bölümler arası nefes. Brief "whitespace" istiyor; cimrilik etme.
  static const double xl = SwanProductSpace.xl;
}
