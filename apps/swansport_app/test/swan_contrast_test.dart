import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/design/swan_palette.dart';

/// Palet okunabilirliği.
///
/// **Neden var:** tasarım yenilemesinde uygulamadaki ~800 renk referansı
/// jetonlara bağlandı. Renk değiştirmek sessiz bir risk taşıyor: analyzer
/// kontrastı umursamaz, testler geçer, ekran açılır — ama metin okunmaz olur
/// ve bunu ancak gözü iyi görmeyen bir kullanıcı fark eder.
///
/// Buradaki eşikler WCAG 2.1 AA: normal metin **4.5:1**, büyük metin
/// (18pt+ ya da 14pt kalın) **3:1**.
///
/// Bir eşleşme burada kalırsa palette dokunma — kombinasyonu düzelt.
double _luminance(Color c) {
  double channel(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  // ignore: deprecated_member_use
  return 0.2126 * channel(c.red.toDouble()) +
      // ignore: deprecated_member_use
      0.7152 * channel(c.green.toDouble()) +
      // ignore: deprecated_member_use
      0.0722 * channel(c.blue.toDouble());
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const normal = 4.5;
  const large = 3.0;

  void check(String what, Color fg, Color bg, double min) {
    final ratio = contrast(fg, bg);
    expect(ratio, greaterThanOrEqualTo(min),
        reason: '$what kontrastı ${ratio.toStringAsFixed(2)}:1 — '
            'en az ${min.toStringAsFixed(1)}:1 olmalı');
  }

  for (final entry in {
    'açık': SwanPalette.light,
    'koyu': SwanPalette.dark,
  }.entries) {
    final theme = entry.key;
    final p = entry.value;

    group('$theme tema — ana metin', () {
      test('ink her yüzeyde okunur', () {
        check('$theme ink/bg', p.ink, p.bg, normal);
        check('$theme ink/surface', p.ink, p.surface, normal);
        check('$theme ink/surfaceAlt', p.ink, p.surfaceAlt, normal);
      });
    });

    group('$theme tema — ikincil metin', () {
      test('inkMuted her yüzeyde okunur', () {
        // Zaman, meta, alt satır — caption boyutunda, yani normal metin eşiği.
        check('$theme inkMuted/bg', p.inkMuted, p.bg, normal);
        check('$theme inkMuted/surface', p.inkMuted, p.surface, normal);
        check('$theme inkMuted/surfaceAlt', p.inkMuted, p.surfaceAlt, normal);
      });
    });

    group('$theme tema — aksiyonlar', () {
      test('dolu düğmede beyaz metin okunur', () {
        // "Giriş Yap", "+" gibi dolu zeminli düğmeler — kalın, büyük.
        // `accent` DEĞİL `accentFill`: ikisi farklı iş yapıyor.
        check('$theme beyaz/accentFill',
            const Color(0xFFFFFFFF), p.accentFill, large);
        check('$theme beyaz/successFill',
            const Color(0xFFFFFFFF), p.successFill, large);
      });

      test('rozetlerde beyaz metin okunur', () {
        // Okunmamış sayacı: küçük ama kalın.
        check('$theme beyaz/danger', const Color(0xFFFFFFFF), p.danger, large);
      });

      test('accent metin olarak yüzeyde okunur', () {
        // Rol etiketi, "Katıl", "Partner bul" gibi teal yazılar.
        check('$theme accent/surface', p.accent, p.surface, large);
        check('$theme accent/bg', p.accent, p.bg, large);
      });
    });
  }
}
