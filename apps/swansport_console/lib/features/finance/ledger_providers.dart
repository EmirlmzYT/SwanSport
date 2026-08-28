import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// Defterin baktığı tarih aralığı.
///
/// Varsayılan içinde bulunulan ay: muhasebecinin en sık sorduğu soru "bu ay ne
/// oldu". Yıl başından beri isteyen aralığı genişletir.
class DateRange {
  const DateRange(this.from, this.to);

  factory DateRange.thisMonth() {
    final now = DateTime.now();
    return DateRange(
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 0),
    );
  }

  final DateTime from;
  final DateTime to;

  String get label =>
      '${_d(from)} – ${_d(to)}';

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final ledgerRangeProvider =
    StateProvider<DateRange>((ref) => DateRange.thisMonth());

/// Yön süzgeci: null = hepsi, 'in' = gelir, 'out' = gider.
final ledgerDirectionProvider = StateProvider<String?>((ref) => null);

/// Gelir–gider defteri.
final ledgerProvider =
    FutureProvider.autoDispose<List<LedgerEntry>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  final range = ref.watch(ledgerRangeProvider);

  final all = await ref
      .watch(expenseServiceProvider)
      .ledger(club.id, from: range.from, to: range.to);

  final dir = ref.watch(ledgerDirectionProvider);
  if (dir == null) return all;
  return all.where((e) => e.direction == dir).toList();
});

/// Seçili aralığın özeti — tabloda değil, üstteki şeritte gösteriliyor.
final ledgerTotalsProvider =
    Provider.autoDispose<({num income, num outgo, num net})>((ref) {
  final rows = ref.watch(ledgerProvider).valueOrNull ?? const <LedgerEntry>[];
  num income = 0;
  num outgo = 0;
  for (final e in rows) {
    // İptal edilmiş/reddedilmiş hareketler toplama girmiyor; taslak giderler de
    // girmiyor çünkü henüz doğrulanmamış bir harcama.
    //
    // Aynı kural tabloda `_countsTowardTotal` içinde de var ve o satırları
    // soluk gösteriyor. İkisi ayrışırsa kullanıcı toplamla satırların neden
    // tutmadığını anlayamaz.
    if (e.status == 'rejected' || e.status == 'draft') continue;
    if (e.isIncome) {
      income += e.amount;
    } else {
      outgo += e.amount;
    }
  }
  return (income: income, outgo: outgo, net: income - outgo);
});

/// Yıllık aylık özet — mali rapor ekranı.
final monthlySummaryProvider =
    FutureProvider.autoDispose.family<List<MonthlyTotals>, int>(
        (ref, year) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).monthlySummary(club.id, year);
});

/// Kategori dağılımı — defterin seçili aralığı için.
final categoryBreakdownProvider =
    FutureProvider.autoDispose<List<CategoryTotal>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  final range = ref.watch(ledgerRangeProvider);
  return ref
      .watch(expenseServiceProvider)
      .categoryBreakdown(club.id, from: range.from, to: range.to);
});

/// Kategori dağılımı — bir yılın tamamı için.
///
/// Rapor ekranı bunu kullanıyor. Önce defterin aralığını kullanıyordu ve aynı
/// ekranda iki farklı dönem görünüyordu: çubuk grafik seçili yılı, kategori
/// paneli içinde bulunulan ayı. Aynı ekrandaki iki sayı farklı dönemden
/// olduğunda kullanıcı hangisine bakacağını bilemiyor.
final yearCategoryBreakdownProvider =
    FutureProvider.autoDispose.family<List<CategoryTotal>, int>(
        (ref, year) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).categoryBreakdown(
        club.id,
        from: DateTime(year, 1, 1),
        to: DateTime(year, 12, 31),
      );
});

/// Tedarikçi önerileri — gider girerken yazım farklarını azaltmak için.
final supplierSuggestionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(expenseServiceProvider).supplierSuggestions(club.id);
});

/// Bir fiş görselinin imzalı adresi (1 saat geçerli).
///
/// Bucket özel; doğrudan URL ile açılmıyor. İmzalı adres her açılışta yeniden
/// üretiliyor — kalıcı bir bağlantı üretmek belgeyi herkese açmak olurdu.
final receiptUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, path) {
  return ref.watch(expenseServiceProvider).receiptUrl(path);
});

/// Tamamlanmayı bekleyen taslak giderler (mobilden fişle girilmiş).
final draftExpensesProvider =
    FutureProvider.autoDispose<List<ExpenseRow>>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref
      .watch(expenseServiceProvider)
      .expenses(club.id, status: 'draft');
});
