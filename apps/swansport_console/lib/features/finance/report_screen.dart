import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';
import 'finance_charts.dart';
import 'ledger_providers.dart';
import 'money.dart';

/// Yılı seçen durum — grafik ve tablo aynı yılı gösteriyor.
final reportYearProvider = StateProvider<int>((ref) => DateTime.now().year);

/// Grafik yerine tablo görünümü.
///
/// Erişilebilirlik gereği: grafikteki her sayı metin olarak da okunabilmeli.
/// Ekran okuyucu kullanan ya da rakamı kopyalamak isteyen için.
final reportTableViewProvider = StateProvider<bool>((ref) => false);

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final year = ref.watch(reportYearProvider);
    final tableView = ref.watch(reportTableViewProvider);
    final monthly = ref.watch(monthlySummaryProvider(year));
    final categories = ref.watch(yearCategoryBreakdownProvider(year));
    final receivables = ref.watch(receivablesProvider);

    return Column(
      children: [
        _Toolbar(year: year, tableView: tableView),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ConsoleDensity.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$year — aylık gelir ve gider',
                    style: t.textTheme.titleMedium),
                const SizedBox(height: ConsoleDensity.lg),
                SizedBox(
                  height: 300,
                  child: monthly.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (e, _) => _err(t, e),
                    data: (rows) => rows.isEmpty
                        ? _empty(t, 'Bu yıl için kayıt yok.')
                        : tableView
                            ? _MonthlyTable(rows: rows)
                            : MonthlyBarChart(
                                months: rows.map((r) => r.month).toList(),
                                incomes: rows.map((r) => r.income).toList(),
                                outgos: rows.map((r) => r.outgo).toList(),
                              ),
                  ),
                ),
                const SizedBox(height: ConsoleDensity.xxl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Panel(
                        title: 'Gider dağılımı',
                        subtitle: '$year yılı',
                        height: 320,
                        child: categories.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          error: (e, _) => _err(t, e),
                          data: (rows) => rows.isEmpty
                              ? _empty(t, 'Bu aralıkta gider yok.')
                              : CategoryBars(
                                  labels:
                                      rows.map((r) => r.category).toList(),
                                  values: rows.map((r) => r.total).toList(),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: ConsoleDensity.xl),
                    Expanded(
                      child: _Panel(
                        title: 'Ödenmemiş aidatlar',
                        subtitle: 'Sporcu kimlikleri gizli',
                        height: 320,
                        child: receivables.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          error: (e, _) => _err(t, e),
                          data: (rows) => rows.isEmpty
                              ? _empty(t, 'Ödenmemiş aidat yok.')
                              : _Receivables(rows: rows),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _err(ThemeData t, Object e) => Center(
        child: SelectableText('Yüklenemedi: $e',
            textAlign: TextAlign.center, style: t.textTheme.bodySmall),
      );

  static Widget _empty(ThemeData t, String s) =>
      Center(child: Text(s, style: t.textTheme.bodySmall));
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.year, required this.tableView});

  final int year;
  final bool tableView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.sm),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<int>(
              initialValue: year,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Yıl'),
              items: [
                for (var y = now; y >= now - 4; y--)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (v) {
                if (v != null) ref.read(reportYearProvider.notifier).state = v;
              },
            ),
          ),
          const Spacer(),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: false,
                  icon: Icon(Icons.bar_chart_rounded, size: 16),
                  label: Text('Grafik')),
              ButtonSegment(
                  value: true,
                  icon: Icon(Icons.table_rows_rounded, size: 16),
                  label: Text('Tablo')),
            ],
            selected: {tableView},
            onSelectionChanged: (s) =>
                ref.read(reportTableViewProvider.notifier).state = s.first,
          ),
        ],
      ),
    );
  }
}

/// Grafiğin metin karşılığı.
class _MonthlyTable extends StatelessWidget {
  const _MonthlyTable({required this.rows});

  final List<MonthlyTotals> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final numStyle = t.textTheme.bodySmall
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return SingleChildScrollView(
      child: DataTable(
        headingRowHeight: ConsoleDensity.headerHeight,
        dataRowMinHeight: ConsoleDensity.rowHeight,
        dataRowMaxHeight: ConsoleDensity.rowHeight,
        columns: const [
          DataColumn(label: Text('Ay')),
          DataColumn(label: Text('Gelir'), numeric: true),
          DataColumn(label: Text('Gider'), numeric: true),
          DataColumn(label: Text('Net'), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text(kMonthNames[r.month - 1],
                  style: t.textTheme.bodySmall)),
              DataCell(Text(fmtMoney(r.income), style: numStyle)),
              DataCell(Text(fmtMoney(r.outgo), style: numStyle)),
              DataCell(Text(
                fmtMoney(r.net),
                style: numStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: r.net < 0 ? t.colorScheme.error : null,
                ),
              )),
            ]),
        ],
      ),
    );
  }
}

class _Receivables extends StatelessWidget {
  const _Receivables({required this.rows});

  final List<Receivable> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: t.colorScheme.outline),
      itemBuilder: (_, i) {
        final r = rows[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
          child: Row(
            children: [
              // Sporcu adı yerine takma gösterim — muhasebeciye açık olan
              // sorgular ismi hiç seçmiyor.
              SizedBox(
                width: 90,
                child: Text(r.athleteCode,
                    style: t.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              StatusPill(
                label: '${r.unpaidCount} fatura',
                tone: r.unpaidCount > 2 ? PillTone.bad : PillTone.warning,
              ),
              const Spacer(),
              Text(fmtMoney(r.total),
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    required this.height,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.textTheme.titleMedium),
        if (subtitle != null)
          Text(subtitle!, style: t.textTheme.bodySmall),
        const SizedBox(height: ConsoleDensity.lg),
        SizedBox(height: height, child: child),
      ],
    );
  }
}
