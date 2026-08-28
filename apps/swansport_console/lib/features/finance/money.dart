/// Para ve tarih biçimlendirme.
///
/// `intl` paketi eklenmedi: tek ihtiyaç Türk Lirası ve gg.aa.yyyy. Bir paket
/// daha getirmek yerine iki küçük fonksiyon yeterli.
library;

/// `12.345,67 ₺` — binlik nokta, ondalık virgül, sonda simge.
String fmtMoney(num value) {
  final negative = value < 0;

  // Once kurusa cevirip tam sayiya yuvarliyoruz. Tam kismi ayirip ondaligi
  // ayrica yuvarlamak, kayan noktali sayilarda 0,01'lik kaymalar uretiyordu.
  final totalCents = (value.abs() * 100).round();
  final whole = totalCents ~/ 100;
  final cents = (totalCents % 100).toString().padLeft(2, '0');

  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }

  return '${negative ? '-' : ''}$buf,$cents ₺';
}

/// `28.08.2026`
String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.'
    '${d.year}';

const List<String> kMonthNames = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];
