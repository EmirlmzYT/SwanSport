import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/modules/console_module.dart';
import '../../app/theme/console_theme.dart';
import '../../app/widgets/console_table.dart';
import '../../app/widgets/csv_export.dart';
import '../../app/widgets/status_pill.dart';
import 'accountants_dialog.dart';
import 'expense_dialog.dart';
import 'ledger_providers.dart';
import 'money.dart';

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
    final drafts = ref.watch(draftExpensesProvider).valueOrNull ?? const [];

    final columns = _columns(context);

    return Column(
      children: [
        _Toolbar(onAdd: () => showExpenseDialog(context, ref)),
        Divider(height: 1, color: t.colorScheme.outline),
        _SummaryStrip(
          income: totals.income,
          outgo: totals.outgo,
          net: totals.net,
          draftCount: drafts.length,
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: ConsoleTable<LedgerEntry>(
            columns: columns,
            rows: entries.valueOrNull ?? const [],
            loading: entries.isLoading,
            error: entries.hasError ? entries.error : null,
            // Defter sunucuda tarihe göre sıralı geliyor ve aralık zaten
            // süzülmüş; sayfalama yerine tek liste gösteriliyor.
            query: const ConsoleTableQuery(pageSize: 100000),
            totalCount: (entries.valueOrNull ?? const []).length,
            rowId: (e) => e.id,
            emptyMessage: 'Bu aralıkta hareket yok.',
            // Yalnızca gider satırları düzenlenebiliyor. Aidat ve bağış
            // kendi akışlarından geliyor; defterden değiştirilmeleri
            // ödeme onayını atlamak olurdu.
            onRowTap: (e) => e.isIncome ? null : _editExpense(context, ref, e),
            onQueryChanged: (_) {},
          ),
        ),
      ],
    );
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
        messenger.showSnackBar(
            const SnackBar(content: Text('Kayıt bulunamadı.')));
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
  const _Toolbar({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(ledgerRangeProvider);
    final dir = ref.watch(ledgerDirectionProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.sm),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _pickRange(context, ref, range),
            icon: const Icon(Icons.date_range_rounded, size: 17),
            label: Text(range.label),
          ),
          const SizedBox(width: ConsoleDensity.sm),
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String?>(
              initialValue: dir,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Yön'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Hepsi')),
                DropdownMenuItem(value: 'in', child: Text('Gelir')),
                DropdownMenuItem(value: 'out', child: Text('Gider')),
              ],
              onChanged: (v) =>
                  ref.read(ledgerDirectionProvider.notifier).state = v,
            ),
          ),
          const Spacer(),
          // Defter erişimi yönetimi yalnızca kulüp yöneticisine görünüyor.
          // Sunucu da aynı şartı uyguluyor; burada gizlemek tek başına koruma
          // değil, yalnızca ilgisiz kişiye anlamsız düğme göstermemek için.
          if (ref.watch(consoleAccessProvider).isClubAdmin) ...[
            OutlinedButton.icon(
              onPressed: () => showAccountantsDialog(context),
              icon: const Icon(Icons.people_outline_rounded, size: 17),
              label: const Text('Defter erişimi'),
            ),
            const SizedBox(width: ConsoleDensity.sm),
          ],
          OutlinedButton.icon(
            onPressed: () async {
              final rows = ref.read(ledgerProvider).valueOrNull ?? const [];
              await downloadCsv(
                fileName: csvFileName('defter'),
                columns: const LedgerScreen()._columns(context),
                rows: rows,
              );
            },
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text('CSV'),
          ),
          const SizedBox(width: ConsoleDensity.sm),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Gider ekle'),
          ),
        ],
      ),
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
