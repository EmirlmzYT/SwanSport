import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Para biçimlendirme.
///
/// Muhasebe ekranında yanlış biçimlenmiş bir tutar sessiz bir hatadır: kimse
/// hata görmez, sadece rakam yanlış okunur. Binlik ayracı ve ondalık en sık
/// karıştırılan yer, o yüzden sınanıyor.
void main() {
  group('fmtMoney', () {
    test('binlik ayracı nokta, ondalık virgül', () {
      expect(fmtMoney(1234.56), '1.234,56 ₺');
      expect(fmtMoney(12345.6), '12.345,60 ₺');
      expect(fmtMoney(1234567.89), '1.234.567,89 ₺');
    });

    test('binden küçük tutarda ayraç yok', () {
      expect(fmtMoney(0), '0,00 ₺');
      expect(fmtMoney(5), '5,00 ₺');
      expect(fmtMoney(999.99), '999,99 ₺');
    });

    test('tam bin sınırında ayraç doğru yerde', () {
      // Sınır değerler: 999/1000 ve 999999/1000000 geçişleri.
      expect(fmtMoney(1000), '1.000,00 ₺');
      expect(fmtMoney(999999), '999.999,00 ₺');
      expect(fmtMoney(1000000), '1.000.000,00 ₺');
    });

    test('negatif tutar başta eksi ile', () {
      // Gider satırları negatif gösteriliyor; eksi ayracın önünde olmalı.
      expect(fmtMoney(-1234.5), '-1.234,50 ₺');
      expect(fmtMoney(-0.5), '-0,50 ₺');
    });

    test('kuruş yuvarlanır, kesilmez', () {
      expect(fmtMoney(1.006), '1,01 ₺');
      expect(fmtMoney(1.994), '1,99 ₺');
      expect(fmtMoney(0.005), '0,01 ₺');
    });

    test('kayan nokta birikimi kuruşu kaydırmıyor', () {
      // 0.1 + 0.2 = 0.30000000000000004; naif bir bölme 0,29 üretebilirdi.
      expect(fmtMoney(0.1 + 0.2), '0,30 ₺');
      expect(fmtMoney(1.1 * 3), '3,30 ₺');
    });

    // Not: 1.005 bilerek sınanmıyor. Double olarak değeri 1.00499999…, yani
    // doğru yuvarlama 1,00. Veritabanında tutarlar numeric(12,2) olduğu için
    // bu aralıkta bir değer zaten gelmiyor.

    test('tam sayıya iki hane eklenir', () {
      expect(fmtMoney(42), '42,00 ₺');
    });
  });

  group('fmtDate', () {
    test('gg.aa.yyyy, tek haneler sıfırla dolduruluyor', () {
      expect(fmtDate(DateTime(2026, 8, 28)), '28.08.2026');
      expect(fmtDate(DateTime(2026, 1, 5)), '05.01.2026');
      expect(fmtDate(DateTime(2026, 12, 31)), '31.12.2026');
    });
  });

  group('kMonthNames', () {
    test('on iki ay var ve sıra doğru', () {
      expect(kMonthNames.length, 12);
      expect(kMonthNames.first, 'Oca');
      expect(kMonthNames[7], 'Ağu');
      expect(kMonthNames.last, 'Ara');
    });

    test('ay numarasından indeks hesabı taşmıyor', () {
      // Grafiklerde kMonthNames[month - 1] kullanılıyor; 1 ve 12 sınırları.
      for (var m = 1; m <= 12; m++) {
        expect(kMonthNames[m - 1], isNotEmpty);
      }
    });
  });
}
