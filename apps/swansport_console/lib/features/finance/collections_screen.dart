import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'work_queue.dart';

/// Tahsilat operasyonları.
///
/// Aidat planı, borç, ödeme bildirimi ve gecikme takibi tek çalışma alanında.
///
/// **Muhasebeci gizliliği burada görünür hale geliyor:** gecikmiş borç
/// listesinde sporcu adı yok, `#A3F91C` biçiminde anonim referans var. Bu bir
/// arayüz kararı değil — `acc_receivables` RPC'si adı hiç seçmiyor, kulüp
/// yöneticisi de aynı listeyi görüyor. Adı görmek gereken veli kendi
/// çocuğunu mobilde isimli görüyor.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final receivables = ref.watch(receivablesProvider);
    final summary = ref.watch(financeOperationsSummaryProvider);

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        const ConsolePageHeader(
          title: 'Tahsilat Operasyonları',
          subtitle: 'Gecikmiş borçlar ve onay bekleyen ödeme bildirimleri. '
              'Listede sporcu adı yerine anonim referans kodu görünür.',
        ),
        const SizedBox(height: ConsoleDensity.xl),

        // Kuyruktan yalnızca tahsilatla ilgili iki kalem.
        AsyncSection<FinanceOperationsSummary>(
          value: summary,
          errorPrefix: 'Özet alınamadı',
          builder: (s) {
            final mine = s.items
                .where((i) =>
                    i.code == 'overdue_invoice' || i.code == 'pending_payment')
                .toList();
            return WorkQueue(
              top: mine,
              emptyTitle: 'Tahsilatta bekleyen iş yok',
              emptyBody: 'Gecikmiş aidat ve onay bekleyen ödeme bildirimi '
                  'bulunmuyor.',
            );
          },
        ),

        const SizedBox(height: ConsoleDensity.xxl),
        Text('Gecikmiş borçlar', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.xs),
        Text(
          'Hatırlatmalar günde bir kez ve üç aşamada gidiyor: vadeden üç gün '
          'önce, vade günü, gecikmenin üçüncü günü. Ödeme bildirimi yapılmış '
          'faturaya hatırlatma gönderilmiyor.',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: ConsoleDensity.lg),
        AsyncSection<List<Receivable>>(
          value: receivables,
          errorPrefix: 'Borç listesi alınamadı',
          builder: (list) => list.isEmpty
              ? Text('Ödenmemiş borç yok.', style: t.textTheme.bodySmall)
              : Column(
                  children: [
                    for (final r in list) _ReceivableRow(row: r),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ReceivableRow extends StatelessWidget {
  const _ReceivableRow({required this.row});

  final Receivable row;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final oldest = row.oldest;
    final overdue = oldest != null && oldest.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: t.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Anonim referans — adın yerine geçen sabit kod.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: ConsoleDensity.sm, vertical: 2),
            decoration: BoxDecoration(
              color: t.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(row.athleteCode,
                style: t.textTheme.labelSmall
                    ?.copyWith(fontFamily: 'monospace')),
          ),
          const SizedBox(width: ConsoleDensity.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${row.unpaidCount} ödenmemiş kayıt',
                    style: t.textTheme.bodyMedium),
                if (oldest != null)
                  Text(
                    overdue
                        ? 'En eskisi ${fmtDate(oldest)} · vadesi geçti'
                        : 'En eski vade ${fmtDate(oldest)}',
                    style: t.textTheme.bodySmall?.copyWith(
                        color: overdue ? t.colorScheme.error : null),
                  ),
              ],
            ),
          ),
          Text(fmtMoney(row.total), style: t.textTheme.titleSmall),
        ],
      ),
    );
  }
}
