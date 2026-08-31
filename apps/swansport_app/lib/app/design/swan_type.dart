import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SwanSport mobil tipografi ölçeği.
///
/// **Neden var:** ölçtüğümde uygulamada **28 farklı yazı boyutu** vardı,
/// 1001 çağrıda — `jakarta(11.5, ...)`, `sora(21, ...)`, `jakarta(13.5, ...)`.
/// Her ekran kendi sayısını uyduruyordu; görsel hiyerarşi bu yüzden
/// kurulamıyordu. Brief'in "tutarlı bir type scale oluştur" demesinin sebebi
/// bu.
///
/// Yedi adım var, ham sayı yazma. Yeni bir boyuta ihtiyaç duyduğunu
/// düşünüyorsan muhtemelen mevcut adımlardan biri işini görüyor.
///
/// Sora başlıklarda (karakterli), Jakarta gövdede (okunabilir) — mevcut
/// tipografik kimlik korunuyor, yalnızca boyutlar disipline giriyor.
class SwanType {
  const SwanType._();

  static TextStyle _sora(double size, FontWeight w, Color c) => GoogleFonts.sora(
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: -0.6,
        height: 1.12,
      );

  static TextStyle _jakarta(double size, FontWeight w, Color c,
          {double height = 1.4}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: w,
        color: c,
        height: height,
      );

  /// 32 — hero, performans skoru. Ekranda en fazla bir tane.
  static TextStyle display(Color c) => _sora(32, FontWeight.w800, c);

  /// 28 — ekran başlığı.
  static TextStyle h1(Color c) => _sora(28, FontWeight.w800, c);

  /// 22 — bölüm başlığı.
  static TextStyle h2(Color c) => _sora(22, FontWeight.w700, c);

  /// 18 — kart/satır başlığı.
  ///
  /// Brief "çok fazla uppercase kullanma" diyor: eski `_label('HIZLI
  /// İŞLEMLER')` gibi büyük harf bölüm başlıkları buraya iniyor.
  static TextStyle h3(Color c) => _sora(18, FontWeight.w700, c);

  /// 16 — ana metin.
  static TextStyle body(Color c, {FontWeight w = FontWeight.w500}) =>
      _jakarta(16, w, c);

  /// 14 — ikincil metin, liste alt satırı.
  static TextStyle bodySm(Color c, {FontWeight w = FontWeight.w500}) =>
      _jakarta(14, w, c);

  /// 12 — etiket, zaman, meta. En küçük adım; bundan aşağısı okunmuyor.
  static TextStyle caption(Color c, {FontWeight w = FontWeight.w600}) =>
      _jakarta(12, w, c, height: 1.3);
}
