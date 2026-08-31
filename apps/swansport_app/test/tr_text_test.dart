import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/util/tr_text.dart';

/// Türkçe arama ve açılış saati mantığı.
///
/// İkisi de "çalışıyor gibi görünüp yanlış cevap veren" cinsten: arama sessizce
/// sonuç bulmuyor, kapalı saha açık görünüyor. Gözle fark edilmesi zor,
/// testle sabitlenmesi kolay.
void main() {
  group('trFold — Türkçe küçültme', () {
    test('Dart toLowerCase Türkçe harfleri olduğu gibi bırakıyor', () {
      // Bu yardımcının VAR OLMA sebebi. Kırılırsa (Dart tam Unicode
      // eşlemesine geçerse) burası söyler ve yardımcı gözden geçirilir.
      expect('Işıklar'.toLowerCase().contains('isiklar'), isFalse);
      expect('Isparta'.toLowerCase().contains('ısparta'), isFalse);

      // Büyük İ ise sorun DEĞİL: Dart düz 'i' üretiyor, birleşik nokta yok.
      // Yardımcıyı yazarken tersini varsaymıştım; ölçüm yanlışladı.
      expect('İlanlar'.toLowerCase().contains('ilan'), isTrue);
    });

    test('noktasız ı ile noktalı i aramada aynı', () {
      expect(trContains('Isparta', 'ısparta'), isTrue);
      expect(trContains('Işıklar Kort', 'isiklar'), isTrue);
    });

    test('diğer Türkçe harfler', () {
      expect(trContains('Şefikcan Parkı', 'sefikcan'), isTrue);
      expect(trContains('Göztepe Sahası', 'goztepe'), isTrue);
      expect(trContains('Çamlıca', 'camlica'), isTrue);
      expect(trContains('Millet Bahçesi Kort 1', 'bahcesi'), isTrue);
    });

    test('eşleşmeyen aramayı bulmaz', () {
      expect(trContains('Millet Bahçesi', 'şefikcan'), isFalse);
    });

    test('boş arama her şeyi eşler', () {
      expect(trContains('herhangi bir şey', ''), isTrue);
    });
  });

  group('isOpenAt — açılış saati', () {
    DateTime at(int h, int m) => DateTime(2026, 8, 31, h, m);

    test('normal aralık', () {
      expect(isOpenAt('08:00', '23:00', at(12, 0)), isTrue);
      expect(isOpenAt('08:00', '23:00', at(7, 59)), isFalse);
      expect(isOpenAt('08:00', '23:00', at(23, 0)), isFalse,
          reason: 'kapanış saatinde artık kapalı');
      expect(isOpenAt('08:00', '23:00', at(22, 59)), isTrue);
    });

    test('24:00 kapanışı gece yarısına kadar açık sayar', () {
      // Halı sahaların varsayılanı bu. Ham karşılaştırmada 24*60 > 0 olduğu
      // için değil, close<=open dalına düşmediği için çalışıyor — yine de
      // sabitliyoruz, varsayılan değişirse burası söyler.
      expect(isOpenAt('08:00', '24:00', at(23, 30)), isTrue);
      expect(isOpenAt('08:00', '24:00', at(7, 0)), isFalse);
    });

    test('gece yarısını aşan aralık', () {
      // 10:00 açılıp 02:00 kapanan bir saha: gece 1'de AÇIK olmalı.
      // Ham `now >= open && now < close` bu durumda hep false dönüyordu.
      expect(isOpenAt('10:00', '02:00', at(1, 0)), isTrue);
      expect(isOpenAt('10:00', '02:00', at(23, 0)), isTrue);
      expect(isOpenAt('10:00', '02:00', at(3, 0)), isFalse);
      expect(isOpenAt('10:00', '02:00', at(9, 59)), isFalse);
    });

    test('saniyeli/bozuk biçimi çökertmez', () {
      // Postgres `time` alanı bazen '08:00:00' olarak geliyor.
      expect(isOpenAt('08:00:00', '23:00:00', at(12, 0)), isTrue);
      expect(() => isOpenAt('', '', at(12, 0)), returnsNormally);
    });
  });
}
