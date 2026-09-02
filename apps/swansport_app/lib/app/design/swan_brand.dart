import 'package:flutter/material.dart';
import 'package:swansport_core/swansport_core.dart';

import 'swan_palette.dart';

/// Marka rengi jetonu — kulüp ve kişi kimliği için.
///
/// **`accent`'İN YERİNE GEÇMİYOR.** `AGENTS.md`: teal yalnızca birincil aksiyon
/// ve aktif durum için; dekoratif teal jetonu bilerek yok. Kırmızı markalı bir
/// kulüpte "Kaydet" düğmesi kırmızı olsaydı `danger` ile aynı görünürdü ve
/// kullanıcı silmeyle kaydetmeyi renkten ayırt edemezdi.
///
/// Marka rengi yalnızca **kimlik yüzeylerinde**: kapak bandı, profil şeridi,
/// rozet dolgusu. Düğme, aktif sekme, bağlantı ve seçim durumu teal kalıyor.
///
/// Üstündeki yazı rengi **ölçülerek** seçiliyor (`swansport_core/color`),
/// tahmin edilmiyor: kullanıcı herhangi bir rengi seçebilir ve beyaz yazı açık
/// sarı bandın üstünde okunmaz.
@immutable
class BrandTone {
  const BrandTone._({
    required this.base,
    required this.ink,
    required this.isCustom,
  });

  /// Kimlik yüzeylerinin zemini.
  final Color base;

  /// [base] üstünde okunabilir yazı rengi. WCAG AA (4.5:1) garantili —
  /// `readableInk` her renkte tutuyor, ölçülerek doğrulandı.
  final Color ink;

  /// Kullanıcı gerçekten bir renk seçti mi. false ise tema accent'ine
  /// düşülmüş demektir ve arayüz "marka rengi yok" durumunu gösterebilir.
  final bool isCustom;

  /// Yumuşak dolgu — rozet ve etiket zemini. Sayfa zemininin üstünde
  /// kullanılıyor, o yüzden yazı `base` oluyor (zemin değil).
  Color get soft => base.withValues(alpha: 0.12);

  /// İnce kimlik şeridi.
  Color get stripe => base;

  /// [hex] geçersiz ya da boşsa temanın accent'ine düşer.
  ///
  /// Düşmek sessiz bir hata değil, bilinçli varsayılan: rengi olmayan bir
  /// kulüp uygulamanın kendi kimliğiyle görünüyor.
  factory BrandTone.from(String? hex, SwanPalette palette) {
    final argb = parseHexColor(hex);
    if (argb == null) {
      return BrandTone._(
        base: palette.accent,
        ink: Color(readableInk(palette.accent.toARGB32())),
        isCustom: false,
      );
    }
    return BrandTone._(
      base: Color(argb),
      ink: Color(readableInk(argb)),
      isCustom: true,
    );
  }
}

/// Kulüplerin gerçek renklerini kapsayan hazır seçenekler.
///
/// Serbest hex de kabul ediliyor; bu liste yalnızca hızlı seçim. Türk spor
/// kulüplerinin yaygın renkleri (kırmızı-beyaz, sarı-lacivert, sarı-kırmızı,
/// siyah-beyaz, yeşil-beyaz) burada karşılığını buluyor.
const List<String> kBrandSwatches = [
  '#E53935', // kırmızı
  '#1E88E5', // mavi
  '#0B1D51', // lacivert
  '#43A047', // yeşil
  '#FDD835', // sarı
  '#FB8C00', // turuncu
  '#8E24AA', // mor
  '#00897B', // teal
  '#6D4C41', // kahve
  '#546E7A', // gri-mavi
  '#212121', // siyah
  '#C2185B', // bordo
];
