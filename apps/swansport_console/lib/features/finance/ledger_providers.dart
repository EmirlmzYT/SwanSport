import '../../app/preferences/console_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/widgets/console_table.dart';

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

  String get label => '${_d(from)} – ${_d(to)}';

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final ledgerRangeProvider = consolePreference<DateRange>(
  'ledger.range',
  clubScoped: true,
  fallback: DateRange.thisMonth,
  decode: (v) {
    if (v is! Map) return DateRange.thisMonth();
    final from =
        DateTime.tryParse(v['from'] is String ? v['from'] as String : '');
    final to = DateTime.tryParse(v['to'] is String ? v['to'] as String : '');
    if (from == null || to == null) return DateRange.thisMonth();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    final now = DateTime.now();
    final maximum = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 365));
    if (start.isAfter(end) || start.isBefore(DateTime(2020)) ||
        end.isAfter(maximum)) return DateRange.thisMonth();
    return DateRange(start, end);
  },
  encode: (v) =>
      {'from': v.from.toIso8601String(), 'to': v.to.toIso8601String()},
);

/// Yön süzgeci: null = hepsi, 'in' = gelir, 'out' = gider.
final ledgerDirectionProvider = consolePreference<String?>(
  'ledger.direction',
  clubScoped: true,
  fallback: () => null,
  decode: (v) => v == 'in' || v == 'out' ? v as String : null,
  encode: (v) => v,
);

/// Sayfa konumu her açılışta sıfırdır; yalnız görünüm tercihleri saklanır.
final ledgerQueryProvider = consolePreference<ConsoleTableQuery>(
  'ledger.query',
  clubScoped: true,
  fallback: () => const ConsoleTableQuery(),
  decode: (v) => decodeConsoleQuery(v),
  encode: encodeConsoleQuery,
);

/// Gelir–gider defteri.
final ledgerProvider = FutureProvider.autoDispose<LedgerPage>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const LedgerPage(entries: [], totalCount: 0);
  final range = ref.watch(ledgerRangeProvider);
  final dir = ref.watch(ledgerDirectionProvider);
  final query = ref.watch(ledgerQueryProvider);
  return ref.watch(expenseServiceProvider).ledger(
        club.id,
        from: range.from,
        to: range.to,
        direction: dir,
        limit: query.pageSize,
        offset: query.offset,
      );
});

/// Seçili aralığın özeti — tabloda değil, üstteki şeritte gösteriliyor.
final ledgerTotalsProvider =
    FutureProvider.autoDispose<LedgerTotals>((ref) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const LedgerTotals.empty();
  final range = ref.watch(ledgerRangeProvider);
  return ref.watch(expenseServiceProvider).ledgerTotals(
        club.id,
        from: range.from,
        to: range.to,
        direction: ref.watch(ledgerDirectionProvider),
      );
});

/// Yıllık aylık özet — mali rapor ekranı.
final monthlySummaryProvider = FutureProvider.autoDispose
    .family<List<MonthlyTotals>, int>((ref, year) async {
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
final yearCategoryBreakdownProvider = FutureProvider.autoDispose
    .family<List<CategoryTotal>, int>((ref, year) async {
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
  return ref.watch(expenseServiceProvider).expenses(club.id, status: 'draft');
});
