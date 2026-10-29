import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/modules/console_module.dart';
import '../../app/theme/console_theme.dart';
import '../../app/widgets/console_table.dart';
import '../../app/widgets/console_detail_panel.dart';
import '../../app/widgets/csv_export.dart';
import '../../app/widgets/status_pill.dart';
import 'accountants_dialog.dart';
import 'expense_dialog.dart';
import 'ledger_providers.dart';

/// Gelir–gider defteri.
///
/// Kulübün para hareketleri tek akışta: aidat ödemeleri, bağışlar ve giderler.
/// Muhasebeci de kulüp yetkilisi de aynı ekranı görür; fark, aidat
/// satırlarında sporcunun adının görünüp görünmemesi — o ayrım veritabanında
/// yapılıyor, burada değil.
class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final entries = ref.watch(ledgerProvider);
    final totals = ref.watch(ledgerTotalsProvider);
    final drafts = ref.watch(draftExpensesProvider);

    final columns = _columns(context);

    return Column(
      children: [
        _Toolbar(
          onAdd: () => showExpenseDialog(context, ref),
          onExport: () => _exportCsv(context, ref),
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        totals.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
              padding: EdgeInsets.all(ConsoleDensity.lg),
              child: Text('Toplamlar yükleniyor…')),
          error: (_, __) => Padding(
              padding: const EdgeInsets.all(ConsoleDensity.lg),
              child: Row(children: [
                const Expanded(child: Text('Toplamlar alınamadı.')),
                TextButton(
                    onPressed: () => ref.invalidate(ledgerTotalsProvider),
                    child: const Text('Tekrar dene'))
              ])),
          data: (value) => _SummaryStrip(
              income: value.income,
              outgo: value.outgo,
              net: value.net,
              draftCount: drafts.valueOrNull?.length ?? 0),
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: ConsoleTable<LedgerEntry>(
            columns: columns,
            rows: entries.valueOrNull?.entries ?? const [],
            loading: entries.isLoading,
            error: entries.hasError ? entries.error : null,
            query: ref.watch(ledgerQueryProvider),
            totalCount: entries.valueOrNull?.totalCount ?? 0,
            rowId: (e) => e.id,
            emptyMessage: 'Bu aralıkta hareket yok.',
            // Yalnızca gider satırları düzenlenebiliyor. Aidat ve bağış
            // kendi akışlarından geliyor; defterden değiştirilmeleri
            // ödeme onayını atlamak olurdu.
            onRowTap: (entry) => _inspectEntry(context, ref, entry),
            onRetry: () => ref.invalidate(ledgerProvider),
            onQueryChanged: (query) =>
                ref.read(ledgerQueryProvider.notifier).state = query,
          ),
        ),
      ],
    );
  }

  void _inspectEntry(BuildContext context, WidgetRef ref, LedgerEntry entry) {
    showConsoleDetailPanel<void>(context,
        title: 'İşlem ayrıntısı',
        action: entry.isIncome
            ? null
            : TextButton.icon(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _editExpense(context, ref, entry);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Gideri düzenle')),
        child: _LedgerDetails(entry: entry));
  }

  /// Defterdeki bir gideri düzenlemek için tam kaydı getirip pencereyi açar.
  ///
  /// Defter satırı özet; düzenleme için kategori, hesap ve fiş yolu gerekiyor
  /// ve onlar `acc_ledger` çıktısında yok.
  Future<void> _editExpense(
      BuildContext context, WidgetRef ref, LedgerEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final row = await ref.read(expenseServiceProvider).expenseById(entry.id);
      if (row == null) {
        messenger
            .showSnackBar(const SnackBar(content: Text('Kayıt bulunamadı.')));
        return;
      }
      if (context.mounted) {
        await showExpenseDialog(context, ref, existing: row);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Açılamadı: $e')));
    }
  }

  List<ConsoleColumn<LedgerEntry>> _columns(BuildContext context) {
    final t = Theme.of(context);
    return [
      ConsoleColumn<LedgerEntry>(
        label: 'Tarih',
        width: 110,
        csv: (e) => fmtDate(e.movedOn),
        cell: (e) => Text(fmtDate(e.movedOn), style: t.textTheme.bodySmall),
      ),
      ConsoleColumn<LedgerEntry>(
        label: 'Yön',
        width: 90,
        csv: (e) => e.isIncome ? 'Gelir' : 'Gider',
        cell: (e) => StatusPill(
          label: e.isIncome ? 'Gelir' : 'Gider',
          tone: e.isIncome ? PillTone.good : PillTone.warning,
        ),
      ),
      ConsoleColumn<LedgerEntry>(
        label: 'Açıklama',
        flex: 3,
        csv: (e) => e.label,
        cell: (e) => Text(e.label,
            overflow: TextOverflow.ellipsis, style: t.textTheme.bodyMedium),
      ),
      ConsoleColumn<LedgerEntry>(
        label: 'Kategori',
        flex: 2,
        csv: (e) => e.category,
        cell: (e) => Text(e.category,
            overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
      ),
      ConsoleColumn<LedgerEntry>(
        label: 'Karşı taraf',
        flex: 2,
        csv: (e) => e.counterpart,
        cell: (e) => Text(e.counterpart,
            overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
      ),
      ConsoleColumn<LedgerEntry>(
        label: 'Hesap',
        flex: 2,
        csv: (e) => e.account,
        cell: (e) => Text(e.account,
            overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
      ),
      // Yalnızca istisnalar rozet alıyor. Her satıra "tamam" yazmak gürültü
      // olurdu; asıl mesele toplama girmeyen satırın belli olması.
      ConsoleColumn<LedgerEntry>(
        label: 'Durum',
        width: 110,
        csv: (e) => _statusLabel(e.status) ?? '',
        cell: (e) {
          final label = _statusLabel(e.status);
          if (label == null) return const SizedBox.shrink();
          return StatusPill(
            label: label,
            tone: e.status == 'rejected' ? PillTone.muted : PillTone.warning,
          );
        },
      ),
      ConsoleColumn<LedgerEntry>(
        label: 'Tutar',
        width: 130,
        numeric: true,
        align: Alignment.centerRight,
        csv: (e) => e.signed.toStringAsFixed(2),
        cell: (e) {
          // Toplama girmeyen satırlar soluk: rakamın neden toplamda
          // görünmediği bakışta anlaşılsın.
          final counted = _countsTowardTotal(e.status);
          return Text(
            fmtMoney(e.signed),
            textAlign: TextAlign.right,
            style: t.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: !counted
                  ? t.colorScheme.outline
                  : (e.isIncome ? null : t.colorScheme.error),
            ),
          );
        },
      ),
    ];
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) return;
      final range = ref.read(ledgerRangeProvider);
      final rows = await ref.read(expenseServiceProvider).ledgerAll(
            club.id,
            from: range.from,
            to: range.to,
            direction: ref.read(ledgerDirectionProvider),
          );
      if (!context.mounted) return;
      await downloadCsv(
        fileName: csvFileName('defter'),
        columns: _columns(context),
        rows: rows,
      );
    } catch (error) {
      messenger
          .showSnackBar(SnackBar(content: Text('CSV oluşturulamadı: $error')));
    }
  }
}

/// Toplama giren satır mı?
///
/// `ledgerTotalsProvider` ile aynı kural — ikisi ayrışırsa tabloda görünen
/// satırlarla üstteki toplam tutmaz ve kimse sebebini bulamaz.
bool _countsTowardTotal(String status) =>
    status != 'rejected' && status != 'draft';

/// İstisna durumların etiketi; normal satırda null.
String? _statusLabel(String status) => switch (status) {
      'draft' => 'Taslak',
      'pending' => 'Bekliyor',
      'rejected' => 'Reddedildi',
      _ => null,
    };

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.onAdd, required this.onExport});

  final VoidCallback onAdd;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(ledgerRangeProvider);
    final dir = ref.watch(ledgerDirectionProvider);

    final query = ref.watch(ledgerQueryProvider);
    return ConsoleToolbar(
      query: query,
      showSearch: false,
      onQueryChanged: (value) =>
          ref.read(ledgerQueryProvider.notifier).state = value,
      onResetFilters: () {
        ref.read(ledgerDirectionProvider.notifier).state = null;
        ref.read(ledgerRangeProvider.notifier).state = DateRange.thisMonth();
        ref.read(ledgerQueryProvider.notifier).state =
            query.copyWith(page: 0, search: '');
      },
      filters: [
        OutlinedButton.icon(
            onPressed: () => _pickRange(context, ref, range),
            icon: const Icon(Icons.date_range_rounded, size: 17),
            label: Text(range.label)),
        SizedBox(
            width: 140,
            child: DropdownButtonFormField<String?>(
              key: ValueKey(dir),
              initialValue: dir,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Yön'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Hepsi')),
                DropdownMenuItem(value: 'in', child: Text('Gelir')),
                DropdownMenuItem(value: 'out', child: Text('Gider'))
              ],
              onChanged: (value) {
                ref.read(ledgerDirectionProvider.notifier).state = value;
                ref.read(ledgerQueryProvider.notifier).state =
                    query.copyWith(page: 0);
              },
            )),
      ],
      onExport: onExport,
      trailing: Wrap(
          spacing: ConsoleDensity.sm,
          runSpacing: ConsoleDensity.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (ref.watch(consoleAccessProvider).isClubAdmin)
              OutlinedButton.icon(
                  onPressed: () => showAccountantsDialog(context),
                  icon: const Icon(Icons.people_outline_rounded, size: 17),
                  label: const Text('Defter erişimi')),
            FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Gider ekle')),
          ]),
    );
  }

  Future<void> _pickRange(
      BuildContext context, WidgetRef ref, DateRange current) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: current.from, end: current.to),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    ref.read(ledgerRangeProvider.notifier).state =
        DateRange(picked.start, picked.end);
    ref.read(ledgerQueryProvider.notifier).state =
        ref.read(ledgerQueryProvider).copyWith(page: 0);
  }
}

/// Aralığın üç sayısı: girdi, çıktı, net.
///
/// Tablonun üstünde duruyor çünkü muhasebecinin ilk baktığı şey bu; satırlara
/// inmeden önce "bu ay ne oldu" cevabı görünür olmalı.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.income,
    required this.outgo,
    required this.net,
    required this.draftCount,
  });

  final num income;
  final num outgo;
  final num net;
  final int draftCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final positive = net >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.md),
      color: t.colorScheme.surface,
      child: Row(
        children: [
          _Figure(label: 'GELİR', value: income, tone: PillTone.good),
          const SizedBox(width: ConsoleDensity.xxl),
          _Figure(label: 'GİDER', value: outgo, tone: PillTone.bad),
          const SizedBox(width: ConsoleDensity.xxl),
          _Figure(
            label: 'NET',
            value: net,
            tone: positive ? PillTone.good : PillTone.bad,
            emphasize: true,
          ),
          const Spacer(),
          if (draftCount > 0)
            Tooltip(
              message: 'Mobilden fişle girilmiş, tamamlanmayı bekliyor.\n'
                  'Toplamlara dahil değil.',
              child: StatusPill(
                label: '$draftCount taslak gider',
                tone: PillTone.warning,
              ),
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.tone,
    this.emphasize = false,
  });

  final String label;
  final num value;
  final PillTone tone;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    final color = switch (tone) {
      PillTone.good => dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      PillTone.bad => dark ? const Color(0xFFFF8189) : const Color(0xFFDC2626),
      _ => t.textTheme.bodyMedium?.color,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          fmtMoney(value),
          style: (emphasize ? t.textTheme.titleLarge : t.textTheme.titleMedium)
              ?.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _LedgerDetails extends StatelessWidget {
  const _LedgerDetails({required this.entry});
  final LedgerEntry entry;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final fields = <(String, String)>[
      ('Tarih', fmtDate(entry.movedOn)),
      ('İşlem', entry.isIncome ? 'Gelir' : 'Gider'),
      ('Tutar', fmtMoney(entry.amount)),
      ('Kategori', entry.category),
      ('Karşı taraf', entry.counterpart),
      ('Hesap', entry.account),
      (
        'Durum',
        _statusLabel(entry.status) ??
            (entry.status == 'confirmed' ? 'Onaylandı' : entry.status)
      ),
    ];
    return ListView(
        padding: const EdgeInsets.all(ConsoleDensity.xl),
        children: [
          Text(entry.label, style: t.textTheme.headlineSmall),
          const SizedBox(height: ConsoleDensity.xl),
          for (final field in fields)
            Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: ConsoleDensity.md),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 120,
                          child: Text(field.$1, style: t.textTheme.bodySmall)),
                      Expanded(
                          child: SelectableText(field.$2,
                              style: t.textTheme.bodyMedium)),
                    ])),
          if (entry.isIncome) ...[
            const SizedBox(height: ConsoleDensity.xl),
            Text('Gelir kayıtları ilgili ödeme veya bağış akışından yönetilir.',
                style: t.textTheme.bodySmall),
          ],
        ]);
  }
}
