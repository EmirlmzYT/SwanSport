import 'package:flutter/material.dart';
import 'package:swansport_product_ui/swansport_product_ui.dart';

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

  /// Atletik marka imzası; ekranlarda ham font çağrısı yapılmaz.
  static TextStyle wordmark(Color c) => SwanProductType.wordmark(c);

  /// Compact navigation brand; reuses the existing 22-point type scale.
  static TextStyle navigationWordmark(Color c) =>
      SwanProductType.navigationWordmark(c);

  /// 32 — hero, performans skoru. Ekranda en fazla bir tane.
  static TextStyle display(Color c) => SwanProductType.display(c);

  /// Sabit genişlikli rakamlarla kronometre; başlık font ailesi korunur.
  static TextStyle stopwatch(Color c) => SwanProductType.stopwatch(c);

  /// 28 — ekran başlığı.
  static TextStyle h1(Color c) => SwanProductType.h1(c);

  /// 22 — bölüm başlığı.
  static TextStyle h2(Color c) => SwanProductType.h2(c);

  /// 18 — kart/satır başlığı.
  ///
  /// Brief "çok fazla uppercase kullanma" diyor: eski `_label('HIZLI
  /// İŞLEMLER')` gibi büyük harf bölüm başlıkları buraya iniyor.
  static TextStyle h3(Color c) => SwanProductType.h3(c);

  /// 16 — ana metin.
  static TextStyle body(Color c, {FontWeight w = FontWeight.w500}) =>
      SwanProductType.body(c, weight: w);

  /// 14 — ikincil metin, liste alt satırı.
  static TextStyle bodySm(Color c, {FontWeight w = FontWeight.w500}) =>
      SwanProductType.bodySm(c, weight: w);

  /// 12 — etiket, zaman, meta. En küçük adım; bundan aşağısı okunmuyor.
  static TextStyle caption(Color c, {FontWeight w = FontWeight.w600}) =>
      SwanProductType.caption(c, weight: w);
}
