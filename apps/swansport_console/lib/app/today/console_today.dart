import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../modules/module_registry.dart';
import '../theme/console_theme.dart';
import '../../features/finance/work_queue.dart';

/// Aggregate queues retain their own scope; only attendance is scoped to today.
List<FinanceWorkItem> consoleTodayItems({
  required SwanAccess access,
  FinanceOperationsSummary? finance,
  ClubOperationsSummary? operations,
  ClubTodayAttendance? attendance,
}) {
  final items = <FinanceWorkItem>[
    if (finance != null) ...finance.topItems,
    if (finance != null) ...finance.otherItems,
    if (operations != null)
      ...operations.items.where((item) =>
          attendance == null || Uri.parse(item.route).path != '/yoklama'),
    if (attendance != null && attendance.trainingCount > attendance.markedCount)
      FinanceWorkItem(
        code: 'today_attendance',
        title: 'Bugünkü yoklama kayıtlarını başlat',
        count: attendance.trainingCount - attendance.markedCount,
        total: 0,
        risk: FinanceRisk.attention,
        why: 'Bugün hiç yoklama kaydı olmayan antrenman oturumları. '
            'Kayıt bulunan oturumların tamamlandığı anlamına gelmez.',
        route: '/yoklama',
      ),
  ]
      .where((item) =>
          item.count > 0 &&
          (moduleForRoute(Uri.parse(item.route).path)?.visibleTo(access) ??
              false))
      .toList();
  items.sort((a, b) {
    final priority = b.risk.index.compareTo(a.risk.index);
    if (priority != 0) return priority;
    return a.code.compareTo(b.code);
  });
  return items;
}

class ConsoleToday extends StatelessWidget {
  const ConsoleToday(
      {super.key,
      required this.access,
      this.finance,
      this.operations,
      this.attendance});
  final SwanAccess access;
  final AsyncValue<FinanceOperationsSummary>? finance;
  final AsyncValue<ClubOperationsSummary>? operations;
  final AsyncValue<ClubTodayAttendance?>? attendance;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final items = consoleTodayItems(
        access: access,
        finance: finance?.isLoading == false && finance?.hasError == false
            ? finance?.valueOrNull
            : null,
        operations:
            operations?.isLoading == false && operations?.hasError == false
                ? operations?.valueOrNull
                : null,
        attendance:
            attendance?.isLoading == false && attendance?.hasError == false
                ? attendance?.valueOrNull
                : null);
    final sources = <(String, AsyncValue<Object?>?)>[
      ('Mali işler', finance),
      ('Kulüp işleri', operations),
      ('Bugünkü yoklama', attendance),
    ];
    final unsettled =
        sources.any((s) => s.$2?.isLoading == true || s.$2?.hasError == true);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ConsoleDensity.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bugün yapacaklarım', style: t.textTheme.titleLarge),
          const SizedBox(height: ConsoleDensity.xs),
          Text(
              'Öncelik sırasıyla bekleyen işler · Yoklama dışındaki kuyruklar tüm açık kayıtları kapsar.',
              style: t.textTheme.bodySmall),
          const SizedBox(height: ConsoleDensity.md),
          for (final source in sources)
            if (source.$2?.isLoading == true || source.$2?.hasError == true)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
                child: Text(
                    source.$2!.hasError
                        ? '${source.$1} alınamadı. Özeti yenileyerek tekrar dene.'
                        : '${source.$1} yükleniyor…',
                    style: t.textTheme.bodySmall),
              ),
          if (items.isEmpty && !unsettled)
            Text('Erişebildiğin kuyruklarda bekleyen iş yok.',
                style: t.textTheme.bodyMedium),
          for (final item in items) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: ConsoleDensity.sm),
              leading: Tooltip(
                  message: riskLabel(item.risk),
                  child: Icon(
                      item.risk == FinanceRisk.critical
                          ? Icons.priority_high_rounded
                          : Icons.pending_actions_outlined,
                      color: item.risk == FinanceRisk.critical
                          ? t.colorScheme.error
                          : t.colorScheme.primary)),
              title: Text('${item.title} · ${item.count} kayıt'),
              subtitle: Text(
                  '${item.why}${item.hasTotal ? ' · ${fmtMoney(item.total)}' : ''}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go(item.route),
            ),
          ],
        ]),
      ),
    );
  }
}
