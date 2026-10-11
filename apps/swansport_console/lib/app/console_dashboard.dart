import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../features/finance/work_queue.dart';
import '../features/finance/expense_dialog.dart';
import 'modules/console_module.dart';
import 'modules/module_registry.dart';
import 'theme/console_theme.dart';

typedef _Metric = ({String value, String detail});

/// Only permitted data sources are watched. An accountant never subscribes
/// to roster, attendance or medical providers through this dashboard.
class ConsoleDashboard extends ConsumerWidget {
  const ConsoleDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final access = ref.watch(consoleAccessProvider);
    final profile = ref.watch(currentProfileProvider);
    final club = ref.watch(activeClubProvider);
    final hasClub = club.valueOrNull != null;
    final showOps = access.isClubStaff;
    final showFinance = access.isClubStaff || access.isAccountant;
    final finance = showFinance && hasClub ? ref.watch(financeOperationsSummaryProvider) : null;
    final ops = showOps && hasClub ? ref.watch(clubOperationsSummaryProvider) : null;
    final roster = showOps && hasClub ? ref.watch(clubRosterCountsProvider) : null;
    final today = showOps && hasClub ? ref.watch(clubTodayAttendanceProvider) : null;
    final risk = showOps && hasClub ? ref.watch(eligibilityBoardProvider) : null;
    final expiringDocs = ops?.valueOrNull?.expiringDocumentCount;
    final documentStatus = expiringDocs != null
        ? '$expiringDocs yaklaşan belge'
        : ops?.hasError == true ? 'Belge özeti alınamadı' : 'Belge özeti bekleniyor';
    final now = ref.watch(clubDashboardDayProvider).add(const Duration(hours: 3));
    final visible = kConsoleModules.where((m) => m.visibleTo(access)).toList();
    if (visible.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      child: Text('Bu hesabın yönetebileceği bir alan görünmüyor.', style: t.textTheme.titleMedium)));

    AsyncValue<_Metric>? metric(bool allowed, AsyncValue<_Metric>? source) {
      if (!allowed) return null;
      if (club.isLoading) return const AsyncLoading();
      if (club.hasError) return AsyncError(club.error!, club.stackTrace ?? StackTrace.empty);
      if (!hasClub) return const AsyncData((value: '—', detail: 'Kulüp seçilmedi'));
      return source;
    }

    final cards = [
      _KpiCard(title: 'Kadro & Sporcular', icon: Icons.groups_rounded,
        route: '/sporcular', enabled: showOps && hasClub,
        data: metric(showOps, roster?.whenData((s) => s == null
          ? (value: '—', detail: 'Kulüp seçilmedi')
          : (value: '${s.total}', detail: '${s.active} aktif sporcu')))),
      _KpiCard(title: 'Mali Kuyruk & Kasa', icon: Icons.account_balance_wallet_outlined,
        route: '/mali-isler', enabled: showFinance && hasClub,
        data: metric(showFinance, finance?.whenData((s) => (
          value: '${s.pendingApprovalCount + s.pendingPaymentCount}',
          detail: '${s.pendingApprovalCount} gider onayı · ${s.pendingPaymentCount} tahsilat onayı')))),
      _KpiCard(title: 'Oturumlar & Yoklama', icon: Icons.event_available_outlined,
        route: '/yoklama', enabled: showOps && hasClub,
        data: metric(showOps, today?.whenData((s) => s == null
          ? (value: '—', detail: 'Kulüp seçilmedi')
          : (value: '${s.trainingCount}', detail: 'Bugün · ${s.markedCount} oturumda yoklama kaydı')))),
      _KpiCard(title: 'Risk & Uygunluk', icon: Icons.health_and_safety_outlined,
        route: '/uygunluk', enabled: showOps && hasClub,
        data: metric(showOps, risk?.whenData((rows) => (
          value: '${rows.where((r) => r.isRestricted).length}',
          detail: 'Uygunluk kısıtı · $documentStatus')))),
    ];
    return ListView(padding: const EdgeInsets.all(ConsoleDensity.xl), children: [
      Wrap(alignment: WrapAlignment.spaceBetween, spacing: ConsoleDensity.xl,
        runSpacing: ConsoleDensity.md, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hoş Geldin${profile.valueOrNull == null ? '' : ', ${profile.valueOrNull!.firstName}'}',
                style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: ConsoleDensity.xs),
            Text('Günün yönetim özeti · ${fmtDate(now)}', style: t.textTheme.bodySmall),
          ]),
          Chip(avatar: const Icon(Icons.shield_outlined, size: 18),
            label: Text(club.isLoading ? 'Kulüp yükleniyor…' : club.hasError ? 'Kulüp alınamadı' : club.valueOrNull?.name ?? 'Kulüp seçilmedi')),
        ]),
      const SizedBox(height: ConsoleDensity.xl),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= ConsoleDensity.dashboardKpiMinWidth * 4 + ConsoleDensity.lg * 3 ? 4 : 2;
        final width = (constraints.maxWidth - ConsoleDensity.lg * (columns - 1)) / columns;
        return Wrap(spacing: ConsoleDensity.lg, runSpacing: ConsoleDensity.lg,
          children: [for (final card in cards) SizedBox(width: width, child: card)]);
      }),
      const SizedBox(height: ConsoleDensity.xl),
      Text('Hızlı Aksiyonlar', style: t.textTheme.titleMedium),
      const SizedBox(height: ConsoleDensity.md),
      Wrap(spacing: ConsoleDensity.sm, runSpacing: ConsoleDensity.sm, children: [
        for (final action in const [
          (Icons.groups_outlined, 'Sporcu Listesi', '/sporcular'),
          (Icons.receipt_long_outlined, 'Gider Gir', '/defter'),
          (Icons.fact_check_outlined, 'Yoklama Al', '/yoklama'),
          (Icons.calendar_month_outlined, 'Takvim', '/takvim'),
        ]) if (moduleForRoute(action.$3)?.visibleTo(access) ?? false)
          OutlinedButton.icon(onPressed: hasClub ? () {
            if (action.$2 == 'Gider Gir') {
              showExpenseDialog(context, ref);
            } else {
              context.go(action.$3);
            }
          } : null,
            icon: Icon(action.$1, size: 18), label: Text(action.$2)),
        if (showFinance && hasClub) OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Özeti yenile'),
          onPressed: () {
            ref.invalidate(financeOperationsSummaryProvider);
            if (showOps) {
              ref.invalidate(clubOperationsSummaryProvider);
              ref.invalidate(clubRosterCountsProvider);
              ref.invalidate(clubTodayAttendanceProvider);
              ref.invalidate(eligibilityBoardProvider);
              ref.invalidate(clubDashboardDayProvider);
            }
          }),
      ]),
      if (access.canPublishFederationResults) ...[
        const SizedBox(height: ConsoleDensity.xl),
        Card(child: ListTile(leading: const Icon(Icons.verified_user_rounded),
          title: const Text('Federasyon'), subtitle: const Text('Sonuç bekleyen resmi müsabakalar'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/federasyon-sonuclari'))),
      ],
      const SizedBox(height: ConsoleDensity.xxl),
      Text('Operasyon Kuyruğu', style: t.textTheme.titleLarge),
      const SizedBox(height: ConsoleDensity.md),
      if (!hasClub && (showFinance || showOps))
        Text(club.hasError ? 'Kulüp bilgisi alınamadı; kuyruk yüklenemiyor.'
            : club.isLoading ? 'Kulüp yükleniyor…' : 'Operasyonları görmek için aktif kulüp seç.', style: t.textTheme.bodySmall),
      LayoutBuilder(builder: (context, constraints) {
        final two = showFinance && showOps && constraints.maxWidth >= ConsoleDensity.dashboardQueueMinWidth * 2 + ConsoleDensity.lg;
        final width = two ? (constraints.maxWidth - ConsoleDensity.lg) / 2 : constraints.maxWidth;
        return Wrap(spacing: ConsoleDensity.lg, runSpacing: ConsoleDensity.lg, children: [
          if (finance != null) SizedBox(width: width, child: _QueuePanel(title: 'Mali İşler',
            icon: Icons.account_balance_wallet_outlined,
            child: AsyncSection<FinanceOperationsSummary>(value: finance, errorPrefix: 'Mali özet alınamadı',
              builder: (s) => WorkQueue(top: s.topItems, others: s.otherItems,
                emptyTitle: 'Şu anda mali işlem beklemiyor',
                emptyBody: 'Bekleyen mali işlemler burada listelenir.')))),
          if (ops != null) SizedBox(width: width, child: _QueuePanel(title: 'Kulüp İşleri',
            icon: Icons.assignment_outlined,
            child: AsyncSection<ClubOperationsSummary>(value: ops, errorPrefix: 'Operasyon özeti alınamadı',
              builder: (s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.expiringDocumentCount} belge 30 gün içinde sona eriyor.', style: t.textTheme.bodySmall),
                const SizedBox(height: ConsoleDensity.md),
                WorkQueue(top: s.items.where((i) => moduleForRoute(Uri.parse(i.route).path)?.visibleTo(access) ?? false).take(5).toList(),
                  others: s.items.where((i) => moduleForRoute(Uri.parse(i.route).path)?.visibleTo(access) ?? false).skip(5).toList(),
                  emptyTitle: 'Erişebildiğin kuyruklarda bekleyen kulüp işi yok',
                  emptyBody: 'Üyelik, belge ve yoklama işleri yetki kapsamına göre gösterilir.'),
              ])))),
        ]);
      }),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.icon, required this.route,
    required this.enabled, required this.data});
  final String title;
  final IconData icon;
  final String route;
  final bool enabled;
  final AsyncValue<_Metric>? data;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final value = data?.when(loading: () => '…', error: (_, __) => '—', data: (s) => s.value) ?? '—';
    final detail = data?.when(loading: () => 'Yükleniyor…', error: (_, __) => 'Veri alınamadı', data: (s) => s.detail) ?? 'Bu alan için yetki gerekli';
    return Card(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: enabled ? () => context.go(route) : null,
        child: Padding(padding: const EdgeInsets.all(ConsoleDensity.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: enabled ? t.colorScheme.primary : t.colorScheme.outline, size: 24),
              const Spacer(), Icon(enabled ? Icons.north_east_rounded : Icons.lock_outline_rounded,
                size: 16, color: t.colorScheme.outline),
            ]),
            const SizedBox(height: ConsoleDensity.md),
            Text(title, style: t.textTheme.titleSmall),
            const SizedBox(height: ConsoleDensity.sm),
            Text(value, style: t.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: ConsoleDensity.xs),
            Text(detail, style: t.textTheme.bodySmall),
          ]))));
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(margin: EdgeInsets.zero, child: Padding(
    padding: const EdgeInsets.all(ConsoleDensity.lg),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: ConsoleDensity.sm), Text(title, style: Theme.of(context).textTheme.titleMedium)]),
      const SizedBox(height: ConsoleDensity.lg), child,
    ])));
}
