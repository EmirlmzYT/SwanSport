import 'package:swansport_core/swansport_core.dart';
import 'package:test/test.dart';

/// Kontrast hesabı.
///
/// Bu matematik uzun süre yalnızca uygulamanın test dosyasında vardı. Marka
/// rengi kullanıcı seçimi olunca çalışma zamanına taşındı — ve taşırken
/// **formülün değişmediğini** kanıtlamak gerekiyordu, yoksa paletin bugünkü
/// geçen kontrast testleri sessizce yanlış bir hesapla geçmeye devam ederdi.
void main() {
  const black = 0xFF000000;
  const white = 0xFFFFFFFF;

  group('Bilinen değerler', () {
    test('siyah–beyaz 21:1', () {
      expect(contrastRatio(black, white), closeTo(21.0, 0.01));
      // Sıra önemsiz olmalı.
      expect(contrastRatio(white, black), closeTo(21.0, 0.01));
    });

    test('aynı renk 1:1', () {
      expect(contrastRatio(0xFF3366CC, 0xFF3366CC), closeTo(1.0, 0.0001));
    });

    test('parlaklık uçları', () {
      expect(relativeLuminance(black), 0.0);
      expect(relativeLuminance(white), closeTo(1.0, 0.0001));
    });

    test('yeşil kırmızıdan parlak — katsayılar doğru yerde', () {
      // WCAG'de yeşilin ağırlığı 0.7152, kırmızının 0.2126.
      expect(relativeLuminance(0xFF00FF00),
          greaterThan(relativeLuminance(0xFFFF0000)));
      expect(relativeLuminance(0xFFFF0000),
          greaterThan(relativeLuminance(0xFF0000FF)));
    });
  });

  group('readableInk', () {
    test('koyu zeminde beyaz', () {
      expect(readableInk(0xFF0B1D51), white); // koyu lacivert
      expect(readableInk(black), white);
    });

    test('açık zeminde siyah', () {
      expect(readableInk(0xFFFFE873), black); // açık sarı
      expect(readableInk(white), black);
    });

    test('seçilen renk her zaman daha yüksek kontrastlı olan', () {
      for (final c in [0xFFE53935, 0xFF1E88E5, 0xFF43A047, 0xFF8E24AA]) {
        final ink = readableInk(c);
        final other = ink == white ? black : white;
        expect(contrastRatio(c, ink),
            greaterThanOrEqualTo(contrastRatio(c, other)));
      }
    });
  });

  group('Okunabilirlik güvencesi', () {
    test('HİÇBİR renk siyah ve beyazın ikisinde birden 4.5:1 kaçırmıyor', () {
      // Bu testin varlık sebebi: plana "dar bir orta-parlaklık bandı kalır,
      // orada rengi koyulaştırırız" diye yazılmıştı. Tarama öyle bir renk
      // bulamadı ve yazılan yedek kod ulaşılamaz olduğu için kaldırıldı.
      //
      // Cebir: beyazla 4.5:1 için L <= 0.1833, siyahla için L >= 0.175.
      // İki aralık ÖRTÜŞÜYOR — arada boşluk yok.
      var checked = 0;
      for (var r = 0; r < 256; r += 5) {
        for (var g = 0; g < 256; g += 5) {
          for (var b = 0; b < 256; b += 5) {
            final c = 0xFF000000 | (r << 16) | (g << 8) | b;
            expect(contrastRatio(c, readableInk(c)),
                greaterThanOrEqualTo(kContrastNormal),
                reason: 'okunamayan renk: '
                    '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}');
            checked++;
          }
        }
      }
      // Tarama gerçekten çalıştı mı — döngü boş kalsaydı test sessizce geçerdi.
      expect(checked, greaterThan(100000));
    });

    test('isReadable varsayılan eşikte her zaman true', () {
      for (final c in [
        0xFF808080, 0xFF767676, 0xFFFFE873, 0xFF0B1D51,
        0xFFE53935, 0xFF00FF00, white, black,
      ]) {
        expect(isReadable(c), isTrue);
      }
    });

    test('AAA eşiğinde (7:1) ayırt ediyor', () {
      // Varsayılan eşikte her şey geçtiği için fonksiyonun anlamlı kaldığı
      // tek yer daha yüksek eşikler.
      expect(isReadable(0xFF767676, threshold: 7.0), isFalse);
      expect(isReadable(black, threshold: 7.0), isTrue);
    });
  });

  group('Hex ayrıştırma', () {
    test('geçerli biçimler', () {
      expect(parseHexColor('#FF0000'), 0xFFFF0000);
      expect(parseHexColor('ff0000'), 0xFFFF0000);
      expect(parseHexColor('  #00FF00  '), 0xFF00FF00);
    });

    test('geçersiz girdi null döner, çökertmez', () {
      // Şemada check kısıtı var ama eski satır ya da elle yazılmış veri
      // buraya bozuk metin düşürebilir. Kimlik rengi yüzünden profil
      // açılmamalı.
      expect(parseHexColor(null), isNull);
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('kırmızı'), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(parseHexColor('#FFF'), isNull);
      expect(parseHexColor('#FF00000'), isNull);
    });

    test('gidiş dönüş kayıpsız', () {
      for (final hex in ['#E53935', '#0B1D51', '#FFE873']) {
        expect(toHexColor(parseHexColor(hex)!), hex);
      }
    });

    test('toHexColor alfayı atıyor', () {
      expect(toHexColor(0x80FF0000), '#FF0000');
    });
  });

  group('Eşikler', () {
    test('WCAG AA değerleri', () {
      expect(kContrastNormal, 4.5);
      expect(kContrastLarge, 3.0);
    });

    test('isReadable eşiği gerçekten kullanıyor', () {
      const mid = 0xFF808080;
      // AA eşiğinde geçiyor (siyahla 5.32:1) — burası ilk yazarken yanlış
      // varsayılmıştı ve test onu yakaladı.
      expect(isReadable(mid, threshold: kContrastNormal), isTrue);
      expect(isReadable(mid, threshold: kContrastLarge), isTrue);
      // AAA eşiğinde kalıyor: parametre bir işe yarıyor.
      expect(isReadable(mid, threshold: 7.0), isFalse);
    });
  });
}
