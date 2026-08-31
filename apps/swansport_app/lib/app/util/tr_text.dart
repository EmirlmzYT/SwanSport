/// Türkçe metin karşılaştırma yardımcıları.
library;

/// Aramada karşılaştırmak için metni sadeleştirir.
///
/// **Sorun `toLowerCase()`'in Türkçe harfleri olduğu gibi bırakması.**
/// Ölçüldü (`test/tr_text_test.dart` sabitliyor):
///
/// ```dart
/// 'Işıklar'.toLowerCase()                      // 'işıklar'
/// 'Işıklar'.toLowerCase().contains('isiklar')  // false
/// 'Isparta'.toLowerCase().contains('ısparta')  // false
/// ```
///
/// Kullanıcı Türkçe klavyesi olmayan bir cihazdan ya da hızlı yazarken
/// "isiklar" yazıyor, "Işıklar Kort" bulunmuyor. Ters yönü de aynı: `I`
/// noktalı `i`'ye düşüyor, `ı` ile aranınca eşleşmiyor.
///
/// Bu yüzden noktalı/noktasız ve şapkalı/şapkasız ayrımı **kaldırılıyor**:
/// aramada `i` ile `ı`, `s` ile `ş` aynı sayılıyor. Kullanıcı hangi klavyeyle
/// yazdığını düşünmek zorunda kalmamalı. Sıralama ya da görüntüleme için
/// kullanma; orası harfleri ayırmayı gerektirir.
///
/// **Büyük `İ` bir sorun değil** — bu yardımcıyı yazarken öyle sandım, ölçünce
/// yanlış çıktı: Dart basit Unicode eşlemesi kullanıyor ve `'İ'.toLowerCase()`
/// birleşik noktalı bir dizi değil, düz `i` üretiyor. Not burada duruyor ki
/// aynı varsayım bir daha yapılmasın.
String trFold(String value) {
  const map = {
    'İ': 'i', 'I': 'i', 'ı': 'i',
    'Ş': 's', 'ş': 's',
    'Ğ': 'g', 'ğ': 'g',
    'Ü': 'u', 'ü': 'u',
    'Ö': 'o', 'ö': 'o',
    'Ç': 'c', 'ç': 'c',
    'Â': 'a', 'â': 'a',
    'Î': 'i', 'î': 'i',
    'Û': 'u', 'û': 'u',
  };
  final buf = StringBuffer();
  for (final ch in value.split('')) {
    buf.write(map[ch] ?? ch.toLowerCase());
  }
  return buf.toString();
}

/// [haystack] içinde [needle] geçiyor mu — Türkçe duyarsız.
///
/// Boş arama her şeyi eşler; "hiçbir şey yazmadım" ile "hiçbir şey bulunamadı"
/// karıştırılmasın diye çağıran tarafta ayrıca kontrol gerekmiyor.
bool trContains(String haystack, String needle) =>
    needle.isEmpty || trFold(haystack).contains(trFold(needle));

/// `HH:mm` biçimindeki açılış/kapanış arasında [at] anı açık mı.
///
/// Gece yarısını aşan aralıkları da doğru sayar: halı sahalarda `closes_at`
/// varsayılanı `24:00` ve bazıları `02:00`'de kapanıyor. Ham
/// `now >= open && now < close` karşılaştırması bu durumda **hep false**
/// dönüyordu — saha bütün gece kapalı görünüyordu.
bool isOpenAt(String opensAt, String closesAt, DateTime at) {
  int mins(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  final now = at.hour * 60 + at.minute;
  final open = mins(opensAt);
  final close = mins(closesAt);

  // '24:00' == '00:00' + bir gün; kapanış açılışa eşit ya da küçükse aralık
  // gece yarısını aşıyor demektir.
  if (close <= open) return now >= open || now < close;
  return now >= open && now < close;
}
