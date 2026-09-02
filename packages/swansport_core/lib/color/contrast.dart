/// WCAG 2.1 kontrast hesabı — **saf Dart**.
///
/// **Neden burada ve neden `Color` değil `int`:** `swansport_core` Flutter'a
/// bağlı değil (`pubspec.yaml`'da yalnızca `sdk` var), o yüzden `dart:ui`
/// tipleri kullanılamıyor. Renkler 0xAARRGGBB tamsayısı olarak geçiyor;
/// uygulama ince bir `Color` sarmalayıcısı yazıyor.
///
/// **Neden testten buraya taşındı:** bu matematik uzun süre yalnızca
/// `swan_contrast_test.dart` içinde vardı. Marka rengi kullanıcı tarafından
/// seçilebilir hale gelince aynı hesap **çalışma zamanında** da gerekti:
/// bandın üstündeki yazının siyah mı beyaz mı olacağına ölçerek karar
/// veriliyor. İki kopya bırakmak, birini düzeltip diğerini unutmak demekti.
///
/// **ÖLÇÜLMÜŞ GÜVENCE:** [readableInk] her renkte 4.5:1'i tutuyor; koyulaştırma
/// gibi bir yedeğe gerek yok. Cebiri şöyle — beyazla 4.5:1 için `L ≤ 0.1833`,
/// siyahla 4.5:1 için `L ≥ 0.175` gerekiyor. İki aralık **örtüşüyor**, yani
/// aralarında boşluk yok ve her parlaklık en az birini sağlıyor. Bu plana
/// "dar bir orta-parlaklık bandı kalır" diye yazılmıştı; RGB uzayı taranınca
/// öyle bir renk bulunamadı ve yazılan yedek kod ulaşılamaz olduğu için
/// kaldırıldı. `contrast_test.dart` bu güvenceyi tarayarak sabitliyor.
///
/// Eşikler: normal metin **4.5:1**, büyük metin (18pt+ ya da 14pt kalın)
/// **3:1**.
library;

import 'dart:math' as math;

/// Normal metin için WCAG AA eşiği.
const double kContrastNormal = 4.5;

/// Büyük metin için WCAG AA eşiği.
const double kContrastLarge = 3.0;

const int _black = 0xFF000000;
const int _white = 0xFFFFFFFF;

int _r(int argb) => (argb >> 16) & 0xFF;
int _g(int argb) => (argb >> 8) & 0xFF;
int _b(int argb) => argb & 0xFF;

double _channel(int v) {
  final s = v / 255.0;
  return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
}

/// Rengin göreli parlaklığı (0 = siyah, 1 = beyaz).
double relativeLuminance(int argb) =>
    0.2126 * _channel(_r(argb)) +
    0.7152 * _channel(_g(argb)) +
    0.0722 * _channel(_b(argb));

/// İki renk arasındaki kontrast oranı. 1.0 (aynı) ile 21.0 (siyah–beyaz).
///
/// Alfa **dikkate alınmıyor**: yarı saydam bir rengin gerçek kontrastı
/// arkasındaki yüzeye bağlı ve o bilgi burada yok. Çağıran, bileşik rengi
/// hesaplayıp öyle geçmeli.
double contrastRatio(int a, int b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// [background] üstünde okunabilecek yazı rengi: siyah ya da beyaz.
///
/// Hangisi daha yüksek kontrast veriyorsa o. Sınıf açıklamasındaki güvence
/// gereği sonuç **her zaman** 4.5:1'i tutuyor.
int readableInk(int background) =>
    contrastRatio(background, _white) >= contrastRatio(background, _black)
        ? _white
        : _black;

/// [background] üstünde seçilen yazı rengi [threshold] eşiğini tutuyor mu.
///
/// Varsayılan eşikte bu **her zaman** true. Fonksiyon yine de duruyor çünkü
/// çağıran daha yüksek bir eşik isteyebilir (ör. 7:1 / AAA) ve o zaman
/// gerçekten ayırt ediyor.
bool isReadable(int background, {double threshold = kContrastNormal}) =>
    contrastRatio(background, readableInk(background)) >= threshold;

/// `#RRGGBB` metnini ARGB tamsayısına çevirir.
///
/// Geçersizse **null** — çökertmiyor. Şemada `check` kısıtı var ama eski
/// satırlar, elle yazılmış veri ya da ileride gevşetilen bir kısıt buraya
/// bozuk metin düşürebilir; kimlik rengi yüzünden profil açılmamalı.
int? parseHexColor(String? hex) {
  if (hex == null) return null;
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length != 6) return null;
  final v = int.tryParse(s, radix: 16);
  return v == null ? null : 0xFF000000 | v;
}

/// ARGB tamsayısını `#RRGGBB` metnine çevirir. Alfa atılıyor.
String toHexColor(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
