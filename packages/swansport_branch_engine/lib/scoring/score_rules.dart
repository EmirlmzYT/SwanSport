/// Skor doğrulama kuralları.
///
/// Sunucu (0072 `submit_set_score`) aynı kuralları uyguluyor ve son sözü o
/// söylüyor. Buradaki kopya kullanıcıya **anında** geri bildirim vermek için:
/// 11 yazan sporcu, sunucuya gidip dönene kadar beklemeden uyarı görüyor.
///
/// EN ÖNEMLİ KURAL: eksik ≠ sıfır. Girilmeyen değer `null` kalıyor.
/// Sıfır yazmak, sporcuyu hiç atmamış gibi değil **kötü atmış** gibi
/// gösterirdi; ortalamayı düşürür ve gelişim grafiğini yalanlar.
library;

/// Skor giriş biçimi.
enum ScoreEntryMode {
  /// Yalnızca set toplamı.
  simple,

  /// Her atış tek tek.
  detailed,

  /// Sporcu ikisinden birini seçiyor.
  flexible;

  static ScoreEntryMode parse(String? raw) => switch (raw) {
        'detailed' => ScoreEntryMode.detailed,
        'flexible' => ScoreEntryMode.flexible,
        _ => ScoreEntryMode.simple,
      };

  bool get allowsDetailed => this != ScoreEntryMode.simple;
  bool get allowsTotalOnly => this != ScoreEntryMode.detailed;
}

/// Doğrulama sonucu. Geçersizse [error] kullanıcıya gösterilecek metin.
class ScoreCheck {
  const ScoreCheck.ok() : error = null;
  const ScoreCheck.fail(this.error);

  final String? error;

  bool get isValid => error == null;
}

/// Tek bir atışın puanı geçerli mi.
///
/// `null` geçerli — atılmamış ok. Bu bilerek böyle.
ScoreCheck checkUnitScore(num? score, {required num maxUnitScore}) {
  if (score == null) return const ScoreCheck.ok();
  if (score < 0) return const ScoreCheck.fail('Puan negatif olamaz');
  if (score > maxUnitScore) {
    return ScoreCheck.fail('En yüksek puan ${_n(maxUnitScore)}');
  }
  return const ScoreCheck.ok();
}

/// Set toplamı geçerli mi.
ScoreCheck checkSetTotal(
  num? total, {
  required int unitsPerSet,
  required num maxUnitScore,
}) {
  if (total == null) return const ScoreCheck.ok();
  if (total < 0) return const ScoreCheck.fail('Puan negatif olamaz');
  final max = unitsPerSet * maxUnitScore;
  if (total > max) {
    return ScoreCheck.fail('Set toplamı en fazla ${_n(max)} olabilir');
  }
  return const ScoreCheck.ok();
}

/// Atış listesi geçerli mi.
ScoreCheck checkEntries(
  List<num?> entries, {
  required int unitsPerSet,
  required num maxUnitScore,
}) {
  if (entries.length > unitsPerSet) {
    return ScoreCheck.fail('Set başına en fazla $unitsPerSet atış var');
  }
  for (final e in entries) {
    final c = checkUnitScore(e, maxUnitScore: maxUnitScore);
    if (!c.isValid) return c;
  }
  return const ScoreCheck.ok();
}

/// Dolu atışların toplamı. Hiç dolu atış yoksa `null` — **sıfır değil**.
num? sumEntries(List<num?> entries) {
  num acc = 0;
  var seen = false;
  for (final e in entries) {
    if (e == null) continue;
    acc += e;
    seen = true;
  }
  return seen ? acc : null;
}

/// Kaç atış girildi (dolu olanlar).
int countEntries(List<num?> entries) => entries.where((e) => e != null).length;

/// Set eksik mi — sunucudaki "eksik sonuç" kavramının istemci karşılığı.
bool isSetMissing(num? total) => total == null;

String _n(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
