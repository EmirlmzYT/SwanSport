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
  static const double sm = 10;

  /// 14 — satır, alan, düğme. Varsayılan bu.
  static const double md = 14;

  /// 22 — yalnızca görsel/hero alanları ve bottom sheet.
  ///
  /// Brief "büyük radius yalnızca görsel/hero alanlarında" diyor; normal
  /// içerik için kullanma.
  static const double lg = 22;
}

class SwanSpace {
  const SwanSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// 16 — ekran kenar boşluğu ve bloklar arası varsayılan.
  static const double lg = 16;

  /// 24 — bölümler arası nefes. Brief "whitespace" istiyor; cimrilik etme.
  static const double xl = 24;
}
