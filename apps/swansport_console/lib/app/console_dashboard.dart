import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../features/finance/expense_dialog.dart';
import '../features/federation/federation_command_center_view.dart';
import 'modules/console_module.dart';
import 'modules/module_registry.dart';
import 'modules/console_workspace.dart';
import 'theme/console_theme.dart';
import 'console_kpi_status.dart';
import 'today/console_today.dart';
import 'today/console_today_referee.dart';

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
    final activeWorkspace = resolveConsoleWorkspace(
        access, ref.watch(consoleWorkspaceProvider), '/');
    final showOps =
        activeWorkspace == ConsoleWorkspace.club && access.isClubStaff;
    final showFinance = activeWorkspace == ConsoleWorkspace.club &&
        (access.isClubStaff || access.isAccountant);
    final finance = showFinance && hasClub
        ? ref.watch(financeOperationsSummaryProvider)
        : null;
    final ops =
        showOps && hasClub ? ref.watch(clubOperationsSummaryProvider) : null;
    final roster =
        showOps && hasClub ? ref.watch(clubRosterCountsProvider) : null;
    final today =
        showOps && hasClub ? ref.watch(clubTodayAttendanceProvider) : null;
    final risk =
        showOps && hasClub ? ref.watch(eligibilityBoardProvider) : null;
    final expiringDocs = ops?.valueOrNull?.expiringDocumentCount;
    final documentStatus = expiringDocs != null
        ? '$expiringDocs yaklaşan belge'
        : ops?.hasError == true
            ? 'Belge özeti alınamadı'
            : 'Belge özeti bekleniyor';
    final now =
        ref.watch(clubDashboardDayProvider).add(const Duration(hours: 3));
    if (activeWorkspace == null) {
      return Center(
          child: Text('Bu hesabın yönetebileceği bir alan görünmüyor.',
              style: t.textTheme.titleMedium));
    }

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        if (activeWorkspace == ConsoleWorkspace.federation)
          ..._buildFederationWidgets(context, ref, t, access, profile, now)
        else if (activeWorkspace == ConsoleWorkspace.referee)
          ..._buildRefereeWidgets(context, ref, t, access, profile, now)
        else if (activeWorkspace == ConsoleWorkspace.platform)
          ..._buildPlatformWidgets(context, ref, t, access, profile, now)
        else
          ..._buildClubWidgets(
            context,
            ref,
            t,
            access,
            profile,
            club,
            hasClub,
            showOps,
            showFinance,
            finance,
            ops,
            roster,
            today,
            risk,
            documentStatus,
            now,
          ),
      ],
    );
  }

  List<Widget> _buildFederationWidgets(
    BuildContext context,
    WidgetRef ref,
    ThemeData t,
    SwanAccess access,
    AsyncValue<ProfileInfo?> profile,
    DateTime now,
  ) {
    return [
      FederationCommandCenterView(
        access: access,
        profile: profile,
        now: now,
      ),
    ];
  }

  List<Widget> _buildRefereeWidgets(
    BuildContext context,
    WidgetRef ref,
    ThemeData t,
    SwanAccess access,
    AsyncValue<ProfileInfo?> profile,
    DateTime now,
  ) {
    return [
      _DashboardHeading(
        title:
            'Hoş Geldin${profile.valueOrNull == null ? '' : ', ${profile.valueOrNull!.firstName}'}',
        detail: 'Görev özeti · ${fmtDate(now)}',
        action: OutlinedButton.icon(
            onPressed: () => context.go('/hakem-gorevleri'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: const Text('Görevlerime git')),
      ),
      const SizedBox(height: ConsoleDensity.xl),
      const ConsoleTodayReferee(),
    ];
  }

  List<Widget> _buildPlatformWidgets(
    BuildContext context,
    WidgetRef ref,
    ThemeData t,
    SwanAccess access,
    AsyncValue<ProfileInfo?> profile,
    DateTime now,
  ) {
    return [
      _DashboardHeading(
        title:
            'Hoş Geldin${profile.valueOrNull == null ? '' : ', ${profile.valueOrNull!.firstName}'}',
        detail: 'Platform özeti · ${fmtDate(now)}',
        action: OutlinedButton.icon(
            onPressed: () => context.go('/onaylar'),
            icon: const Icon(Icons.fact_check_outlined, size: 17),
            label: const Text('Onayları incele')),
      ),
      const SizedBox(height: ConsoleDensity.xl),
      _buildKpiGrid([
        const _KpiCard(
          title: 'Platform Mission Control',
          icon: Icons.admin_panel_settings_rounded,
          route: '/mission-control',
          enabled: true,
          data: AsyncData((
            value: 'Sistem',
            detail: 'Şalterler, paketler, komisyon & marka'
          )),
        ),
        const _KpiCard(
          title: 'Onay & Belge Kuyruğu',
          icon: Icons.verified_rounded,
          route: '/onaylar',
          enabled: true,
          data: AsyncData((
            value: 'Onaylar',
            detail: 'Kulüp başvuruları ve belge onayları'
          )),
        ),
        const _KpiCard(
          title: 'Kullanıcı & Moderasyon',
          icon: Icons.badge_rounded,
          route: '/kullanicilar',
          enabled: true,
          data: AsyncData((
            value: 'Kullanıcı',
            detail: 'Platform hesapları ve içerik denetimi'
          )),
        ),
        const _KpiCard(
          title: 'Hata & Teşhis Masası',
          icon: Icons.bug_report_outlined,
          route: '/hata-merkezi',
          enabled: true,
          data: AsyncData(
              (value: 'Teşhis', detail: 'Hata logları ve otomatik onarım')),
        ),
      ]),
      const SizedBox(height: ConsoleDensity.xl),
      Row(
        children: [
          Icon(Icons.bolt_rounded, size: 19, color: t.colorScheme.primary),
          const SizedBox(width: ConsoleDensity.xs),
          Text('Platform Hızlı Aksiyonları', style: t.textTheme.titleMedium),
        ],
      ),
      const SizedBox(height: ConsoleDensity.md),
      _buildActionGroupsGrid(context, [
        (
          'Sistem ve Yapılandırma',
          [
            (
              Icons.admin_panel_settings_outlined,
              'Mission Control',
              '/mission-control'
            ),
            (Icons.toggle_on_outlined, 'Özellik Bayrakları', '/bayraklar'),
            (Icons.bug_report_outlined, 'Hata Merkezi', '/hata-merkezi'),
          ]
        ),
        (
          'Onay ve Destek',
          [
            (Icons.verified_outlined, 'Onay Kuyruğu', '/onaylar'),
            (Icons.badge_outlined, 'Kullanıcılar', '/kullanicilar'),
            (Icons.flag_outlined, 'Moderasyon', '/moderasyon'),
            (Icons.support_agent_outlined, 'Destek Masası', '/destek'),
          ]
        ),
      ]),
    ];
  }

  List<Widget> _buildClubWidgets(
    BuildContext context,
    WidgetRef ref,
    ThemeData t,
    SwanAccess access,
    AsyncValue<ProfileInfo?> profile,
    AsyncValue<ClubRef?> club,
    bool hasClub,
    bool showOps,
    bool showFinance,
    AsyncValue<FinanceOperationsSummary>? finance,
    AsyncValue<ClubOperationsSummary>? ops,
    AsyncValue<ClubRosterCounts?>? roster,
    AsyncValue<ClubTodayAttendance?>? today,
    AsyncValue<List<EligibilityRow>>? risk,
    String documentStatus,
    DateTime now,
  ) {
    AsyncValue<_Metric>? metric(bool allowed, AsyncValue<_Metric>? source) {
      if (!allowed) {
        return null;
      }
      if (club.isLoading) {
        return const AsyncLoading();
      }
      if (club.hasError) {
        return AsyncError(club.error!, club.stackTrace ?? StackTrace.empty);
      }
      if (!hasClub) {
        return const AsyncData((value: '—', detail: 'Kulüp seçilmedi'));
      }
      return source;
    }

    final r = roster?.isLoading == false && roster?.hasError == false
        ? roster?.valueOrNull
        : null;
    final a = today?.isLoading == false && today?.hasError == false
        ? today?.valueOrNull
        : null;
    final f = finance?.isLoading == false && finance?.hasError == false
        ? finance?.valueOrNull
        : null;
    final e = risk?.isLoading == false && risk?.hasError == false
        ? risk?.valueOrNull
        : null;

    final cards = [
      if (showOps)
        _KpiCard(
          title: 'Kadro & Sporcular',
          icon: Icons.groups_rounded,
          route: '/sporcular',
          enabled: showOps && hasClub,
          status: r == null ? null : ConsoleKpiStatus.roster(r.total, r.active),
          data: metric(
            showOps,
            roster?.whenData(
              (s) => s == null
                  ? (value: '—', detail: 'Kulüp seçilmedi')
                  : (value: '${s.total}', detail: '${s.active} aktif sporcu'),
            ),
          ),
        ),
      _KpiCard(
        title: 'Mali Kuyruk & Kasa',
        icon: Icons.account_balance_wallet_outlined,
        route: '/mali-isler',
        enabled: showFinance && hasClub,
        status: f == null
            ? null
            : ConsoleKpiStatus.finance(
                f.pendingApprovalCount + f.pendingPaymentCount),
        data: metric(
          showFinance,
          finance?.whenData(
            (s) => (
              value: '${s.pendingApprovalCount + s.pendingPaymentCount}',
              detail:
                  '${s.pendingApprovalCount} gider onayı · ${s.pendingPaymentCount} tahsilat onayı',
            ),
          ),
        ),
      ),
      if (showOps)
        _KpiCard(
          title: 'Oturumlar & Yoklama',
          icon: Icons.event_available_outlined,
          route: '/yoklama',
          enabled: showOps && hasClub,
          status: a == null
              ? null
              : ConsoleKpiStatus.attendance(a.trainingCount, a.markedCount),
          data: metric(
            showOps,
            today?.whenData(
              (s) => s == null
                  ? (value: '—', detail: 'Kulüp seçilmedi')
                  : (
                      value: '${s.trainingCount}',
                      detail: 'Bugün · ${s.markedCount} oturumda yoklama kaydı'
                    ),
            ),
          ),
        ),
      if (showOps)
        _KpiCard(
          title: 'Risk & Uygunluk',
          icon: Icons.health_and_safety_outlined,
          route: '/uygunluk',
          enabled: showOps && hasClub,
          status: e == null
              ? null
              : ConsoleKpiStatus.risk(e.where((r) => r.isRestricted).length),
          data: metric(
            showOps,
            risk?.whenData(
              (rows) => (
                value: '${rows.where((r) => r.isRestricted).length}',
                detail: 'Uygunluk kısıtı · $documentStatus',
              ),
            ),
          ),
        ),
    ];

    const groups = [
      (
        'Kadro & Sporcu',
        [
          (Icons.groups_outlined, 'Sporcu Listesi', '/sporcular'),
          (Icons.pie_chart_outline_rounded, 'Kadro Dağılımı', '/sporcular'),
        ]
      ),
      (
        'Antrenman & Takvim',
        [
          (Icons.fact_check_outlined, 'Yoklama Al', '/yoklama'),
          (Icons.stadium_outlined, 'Tesis Rezervasyonu', '/tesisler'),
          (Icons.calendar_month_outlined, 'Takvim', '/takvim'),
        ]
      ),
      (
        'Mali Defter & Kasa',
        [
          (Icons.receipt_long_outlined, 'Gider Gir', '/defter'),
          (Icons.request_quote_outlined, 'Tahsilat Onayı', '/tahsilat'),
        ]
      ),
    ];

    final available = groups
        .where(
          (g) => g.$2.any(
            (action) => moduleForRoute(action.$3)?.visibleTo(access) ?? false,
          ),
        )
        .toList();

    return [
      _DashboardHeading(
        title:
            'Hoş Geldin${profile.valueOrNull == null ? '' : ', ${profile.valueOrNull!.firstName}'}',
        detail: 'Kulüp özeti · ${fmtDate(now)}',
        action: OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Özeti yenile'),
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
      ),
      const SizedBox(height: ConsoleDensity.xl),
      if (!hasClub && (showFinance || showOps))
        Text(club.hasError
            ? 'Kulüp bilgisi alınamadı; kuyruk yüklenemiyor.'
            : club.isLoading
                ? 'Kulüp yükleniyor…'
                : 'Operasyonları görmek için aktif kulüp seç.'),
      if (hasClub)
        ConsoleToday(
            access: access,
            finance: finance,
            operations: ops,
            attendance: today),
      const SizedBox(height: ConsoleDensity.xl),
      _buildKpiGrid(cards),
      const SizedBox(height: ConsoleDensity.xxl),
      Row(
        children: [
          Icon(Icons.bolt_rounded, size: 19, color: t.colorScheme.primary),
          const SizedBox(width: ConsoleDensity.xs),
          Text('Sık kullanılanlar', style: t.textTheme.titleMedium),
        ],
      ),
      const SizedBox(height: ConsoleDensity.md),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >=
                  ConsoleDensity.dashboardActionMinWidth * 3 +
                      ConsoleDensity.lg * 2
              ? 3
              : constraints.maxWidth >=
                      ConsoleDensity.dashboardActionMinWidth * 2 +
                          ConsoleDensity.lg
                  ? 2
                  : 1;
          final width =
              (constraints.maxWidth - ConsoleDensity.lg * (columns - 1)) /
                  columns;
          return Wrap(
            spacing: ConsoleDensity.lg,
            runSpacing: ConsoleDensity.lg,
            children: [
              for (final group in available)
                SizedBox(
                  width: width,
                  child: _ActionGroup(
                    title: group.$1,
                    actions: [
                      for (final action in group.$2)
                        if (moduleForRoute(action.$3)?.visibleTo(access) ??
                            false)
                          OutlinedButton.icon(
                            onPressed: hasClub &&
                                    (action.$2 != 'Kadro Dağılımı' || r != null)
                                ? () {
                                    if (action.$2 == 'Gider Gir') {
                                      showExpenseDialog(context, ref);
                                    } else if (action.$2 == 'Kadro Dağılımı') {
                                      showDialog<void>(
                                        context: context,
                                        builder: (_) =>
                                            _RosterDistribution(counts: r!),
                                      );
                                    } else {
                                      context.go(action.$3);
                                    }
                                  }
                                : null,
                            icon: Icon(action.$1, size: 17),
                            label: Text(action.$2),
                          ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }

  static Widget _buildKpiGrid(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >=
                ConsoleDensity.dashboardKpiMinWidth * 4 + ConsoleDensity.lg * 3
            ? 4
            : 2;
        final width =
            (constraints.maxWidth - ConsoleDensity.lg * (columns - 1)) /
                columns;
        return Wrap(
          spacing: ConsoleDensity.lg,
          runSpacing: ConsoleDensity.lg,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  static Widget _buildActionGroupsGrid(
    BuildContext context,
    List<(String, List<(IconData, String, String)>)> groups,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >=
                ConsoleDensity.dashboardActionMinWidth * 3 +
                    ConsoleDensity.lg * 2
            ? 3
            : constraints.maxWidth >=
                    ConsoleDensity.dashboardActionMinWidth * 2 +
                        ConsoleDensity.lg
                ? 2
                : 1;
        final width =
            (constraints.maxWidth - ConsoleDensity.lg * (columns - 1)) /
                columns;
        return Wrap(
          spacing: ConsoleDensity.lg,
          runSpacing: ConsoleDensity.lg,
          children: [
            for (final group in groups)
              SizedBox(
                width: width,
                child: _ActionGroup(
                  title: group.$1,
                  actions: [
                    for (final action in group.$2)
                      OutlinedButton.icon(
                        onPressed: () => context.go(action.$3),
                        icon: Icon(action.$1, size: 17),
                        label: Text(action.$2),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.icon,
    required this.route,
    required this.enabled,
    required this.data,
    this.status,
  });
  final String title;
  final IconData icon;
  final String route;
  final bool enabled;
  final AsyncValue<_Metric>? data;
  final ConsoleKpiStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final value = data?.when(
          loading: () => '…',
          error: (_, __) => '—',
          data: (s) => s.value,
        ) ??
        '—';
    final detail = data?.when(
          loading: () => 'Yükleniyor…',
          error: (_, __) => 'Veri alınamadı',
          data: (s) => s.detail,
        ) ??
        'Bu alan için yetki gerekli';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? () => context.go(route) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ConsoleDensity.dashboardKpiHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(ConsoleDensity.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: enabled
                            ? t.colorScheme.primary.withValues(alpha: .14)
                            : t.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: enabled
                            ? t.colorScheme.primary
                            : t.colorScheme.outline,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: t.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        enabled
                            ? Icons.north_east_rounded
                            : Icons.lock_outline_rounded,
                        size: 15,
                        color: enabled
                            ? t.colorScheme.primary
                            : t.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ConsoleDensity.md),
                Text(title, style: t.textTheme.titleSmall),
                const SizedBox(height: ConsoleDensity.sm),
                Text(
                  value,
                  style: t.textTheme.headlineMedium?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: ConsoleDensity.xs),
                Text(detail, style: t.textTheme.bodySmall),
                if (status != null &&
                    enabled &&
                    data?.isLoading == false &&
                    data?.hasError == false) ...[
                  const SizedBox(height: ConsoleDensity.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ConsoleDensity.sm + 2,
                      vertical: ConsoleDensity.xs,
                    ),
                    decoration: BoxDecoration(
                      color: t.colorScheme.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: t.colorScheme.primary.withValues(alpha: .30),
                      ),
                    ),
                    child: Text(
                      status!.label,
                      style: t.textTheme.labelMedium?.copyWith(
                        color: t.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (status!.progress != null) ...[
                    const SizedBox(height: ConsoleDensity.md),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(ConsoleDensity.radius),
                      child: LinearProgressIndicator(
                        value: status!.progress,
                        minHeight: 6,
                        backgroundColor:
                            t.colorScheme.primary.withValues(alpha: .10),
                        semanticsLabel: status!.label,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.title, required this.actions});
  final String title;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(ConsoleDensity.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.primary,
              ),
            ),
            const SizedBox(height: ConsoleDensity.md),
            Wrap(
              spacing: ConsoleDensity.sm,
              runSpacing: ConsoleDensity.sm,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterDistribution extends StatelessWidget {
  const _RosterDistribution({required this.counts});
  final ClubRosterCounts counts;
  @override
  Widget build(BuildContext context) {
    final status = ConsoleKpiStatus.roster(counts.total, counts.active);
    return AlertDialog(
      title: const Text('Kadro Dağılımı'),
      content: SizedBox(
        width: ConsoleDensity.dashboardActionMinWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status.label),
            const SizedBox(height: ConsoleDensity.lg),
            Text('Toplam: ${counts.total}'),
            Text('Aktif: ${counts.active}'),
            if (status.progress != null) ...[
              Text('Aktif olmayan: ${counts.total - counts.active}'),
              const SizedBox(height: ConsoleDensity.md),
              LinearProgressIndicator(
                value: status.progress,
                semanticsLabel: status.label,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading(
      {required this.title, required this.detail, required this.action});
  final String title;
  final String detail;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ConsoleDensity.md),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: ConsoleDensity.xl,
          runSpacing: ConsoleDensity.lg,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.textTheme.headlineMedium),
              const SizedBox(height: ConsoleDensity.sm),
              Text(detail, style: t.textTheme.bodySmall),
            ]),
            action,
          ]),
    );
  }
}
