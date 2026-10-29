import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../app/pro_theme.dart';
import '../../widgets/pro_ui_components.dart';
import '../../workspaces/pro_workspace.dart';
import '../../workspaces/pro_workspace_controller.dart';
import '../operations/pro_club_context_selector.dart';
import '../operations/pro_feature_host.dart';
import '../operations/pro_tasks_controller.dart';

class ProDashboardScreen extends ConsumerWidget {
  const ProDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    if (workspace == null) {
      return const Scaffold(
        body: Center(child: Text('Çalışma alanı bulunamadı.')),
      );
    }
    final supportsFederation = workspace.supportsFederationOperations;
    final supportsReferee = workspace.supportsRefereeOperations;
    final supportsAccounting = workspace.supportsAccountingOperations;
    final supportsFacility = workspace.supportsFacilityOperations;
    final supportsPlatform = workspace.supportsPlatformOperations;
    final access = ref.watch(swanAccessProvider);
    final clubs = ref.watch(proAuthorizedClubsProvider);

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            children: [
              _WorkspaceHeader(
                workspaceLabel: workspace.label,
                onRefresh: () {
                  ref.invalidate(proAuthorizedClubsProvider);
                  ref.invalidate(activeClubProvider);
                },
              ),
              const SizedBox(height: 20),
              _TodaySection(workspace: workspace),
              const SizedBox(height: 20),
              _QuickActionsRow(workspace: workspace),
              const SizedBox(height: 24),
              const ProSectionHeader(
                title: 'Operasyon Yönetimi',
                subtitle: 'Tüm yetkili modüller ve araçlar',
              ),
              const SizedBox(height: 12),
              if (supportsFederation)
                const ProOperationsFeatureHost(
                  child: SharedFederationOperationsPanel(),
                )
              else if (supportsReferee)
                const ProOperationsFeatureHost(
                  child: SharedRefereeOperationsPanel(),
                )
              else if (supportsAccounting)
                const ProOperationsFeatureHost(
                  child: SharedAccountingOperationsPanel(),
                )
              else if (supportsFacility)
                const ProOperationsFeatureHost(
                  child: SharedFacilityOperationsPanel(),
                )
              else if (supportsPlatform)
                const ProOperationsFeatureHost(
                  child: SharedPlatformOperationsPanel(),
                )
              else
                clubs.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => ProErrorState(
                    message: classifyOperationError(error).userMessage,
                    onRetry: () => ref.invalidate(proAuthorizedClubsProvider),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const ProEmptyState(
                        icon: Icons.lock_person_outlined,
                        title: 'Aktif kulüp operasyon yetkisi yok',
                        subtitle:
                            'Bu çalışma alanını açan kimliğin var ancak aktif kulüp yöneticisi veya antrenör üyeliğin bulunmuyor.',
                      );
                    }
                    return ProOperationsFeatureHost(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (access.hasActiveClubStaffMembership)
                            const SharedClubOperationsPanel(),
                          if (access.hasActiveClubStaffMembership &&
                              access.hasOperationalClubRole)
                            const SizedBox(height: 28),
                          if (access.hasOperationalClubRole)
                            const SharedClubStaffOperationsPanel(),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              const _CompactSecurityFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceHeader extends ConsumerWidget {
  const _WorkspaceHeader({
    required this.workspaceLabel,
    this.onRefresh,
  });

  final String workspaceLabel;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12314A), Color(0xFF0E1B2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ProTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ProTheme.primary.withValues(alpha: 0.28),
              ),
            ),
            child: const Icon(
              Icons.space_dashboard_rounded,
              color: ProTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$workspaceLabel Paneli',
                  style: const TextStyle(
                    color: ProTheme.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Bugünkü operasyonlarını tek ekrandan yönet.',
                  style: TextStyle(
                    color: ProTheme.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ProTheme.muted),
            tooltip: 'Yenile',
            onPressed: () {
              ref.invalidate(proPendingTasksCountProvider);
              onRefresh?.call();
            },
          ),
        ],
      ),
    );
  }
}

class _TodaySection extends ConsumerWidget {
  const _TodaySection({required this.workspace});

  final ProWorkspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = _buildTodayItems(context, ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProSectionHeader(
          title: 'Bugün',
          subtitle: 'En önemli operasyonel durumlar',
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ProTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ProTheme.line),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: ProTheme.secondary, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bugün için bekleyen acil işlem yok',
                        style: TextStyle(
                          color: ProTheme.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tüm operasyonel süreçler güncel ve yolunda.',
                        style: TextStyle(
                          color: ProTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...items.take(3).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: item,
                ),
              ),
      ],
    );
  }

  List<Widget> _buildTodayItems(BuildContext context, WidgetRef ref) {
    final list = <Widget>[];
    switch (workspace) {
      case ProWorkspace.referee:
        final matches =
            ref.watch(refereeDutyMatchesProvider).valueOrNull ?? const [];
        final pending = matches
            .where((m) =>
                m.matchStatus == 'scheduled' &&
                m.status == MatchOfficialStatus.assigned)
            .length;
        if (pending > 0) {
          list.add(
            _TodayItemCard(
              icon: Icons.assignment_late_outlined,
              tone: _ItemTone.warning,
              title: 'Yanıt Bekleyen Görevler',
              subtitle: '$pending müsabaka ataması kabul veya ret bekliyor.',
              actionLabel: 'Görevler',
              onTap: () => context.go('/gorevler'),
            ),
          );
        }
        final accepted = matches
            .where((m) =>
                m.matchStatus == 'scheduled' &&
                m.status == MatchOfficialStatus.accepted)
            .length;
        if (accepted > 0) {
          list.add(
            _TodayItemCard(
              icon: Icons.sports_rounded,
              tone: _ItemTone.info,
              title: 'Yaklaşan Müsabakalar',
              subtitle: '$accepted kabul edilmiş maç takvimde seni bekliyor.',
              actionLabel: 'Takvim',
              onTap: () => context.go('/takvim'),
            ),
          );
        }
        break;

      case ProWorkspace.accounting:
        final summary = ref.watch(financeOperationsSummaryProvider).valueOrNull;
        if (summary != null && summary.pendingApprovalCount > 0) {
          list.add(
            _TodayItemCard(
              icon: Icons.pending_actions_outlined,
              tone: _ItemTone.warning,
              title: 'Onay Bekleyen Harcamalar',
              subtitle:
                  '${summary.pendingApprovalCount} gider onayı inceleme bekliyor.',
              actionLabel: 'İncele',
              onTap: () => context.push('/operasyon/muhasebe/onaylar'),
            ),
          );
        }
        if (summary != null && summary.bankUnmatchedCount > 0) {
          list.add(
            _TodayItemCard(
              icon: Icons.account_balance_wallet_outlined,
              tone: _ItemTone.warning,
              title: 'Eşleşmeyen Banka Hareketleri',
              subtitle:
                  '${summary.bankUnmatchedCount} banka işlemi mutabakat bekliyor.',
              actionLabel: 'Mutabakat',
              onTap: () => context.push('/operasyon/muhasebe/banka'),
            ),
          );
        }
        break;

      case ProWorkspace.federation:
        final pending =
            ref.watch(federationPendingResultsProvider(0)).valueOrNull ??
                const [];
        if (pending.isNotEmpty) {
          list.add(
            _TodayItemCard(
              icon: Icons.how_to_reg_outlined,
              tone: _ItemTone.warning,
              title: 'Sonuç & Atama Bekleyenler',
              subtitle:
                  '${pending.length} müsabaka sonuç girişi veya hakem ataması bekliyor.',
              actionLabel: 'İncele',
              onTap: () => context.go('/gorevler'),
            ),
          );
        }
        break;

      case ProWorkspace.facility:
        final duties =
            ref.watch(turfDutiesProvider(0)).valueOrNull?.items ?? const [];
        if (duties.isNotEmpty) {
          list.add(
            _TodayItemCard(
              icon: Icons.stadium_outlined,
              tone: _ItemTone.info,
              title: 'Tesis Görevleri',
              subtitle: '${duties.length} saha ve bakım operasyonu planlandı.',
              actionLabel: 'Görevler',
              onTap: () => context.go('/gorevler'),
            ),
          );
        }
        break;

      case ProWorkspace.platform:
        final waitlist = ref.watch(launchWaitlistSummaryProvider).valueOrNull;
        if (waitlist != null && waitlist.totalCount > 0) {
          list.add(
            _TodayItemCard(
              icon: Icons.people_outline_rounded,
              tone: _ItemTone.warning,
              title: 'Bekleme Listesi',
              subtitle:
                  '${waitlist.totalCount} başvuru onay ve inceleme bekliyor.',
              actionLabel: 'İncele',
              onTap: () => context.push('/operasyon/platform/bekleme-listesi'),
            ),
          );
        }
        break;

      case ProWorkspace.club:
      case ProWorkspace.coaching:
        final pendingApps =
            ref.watch(clubPendingApplicationsProvider).valueOrNull ?? const [];
        if (pendingApps.isNotEmpty) {
          list.add(
            _TodayItemCard(
              icon: Icons.group_add_outlined,
              tone: _ItemTone.warning,
              title: 'Bekleyen Başvurular',
              subtitle:
                  '${pendingApps.length} sporcu veya üye başvurusu onay bekliyor.',
              actionLabel: 'İncele',
              onTap: () => context.push('/operasyon/kulup/basvurular'),
            ),
          );
        }
        final todayAttendance =
            ref.watch(clubTodayAttendanceProvider).valueOrNull;
        if (todayAttendance != null) {
          final unrecorded =
              (todayAttendance.trainingCount - todayAttendance.markedCount)
                  .clamp(0, 999);
          if (unrecorded > 0) {
            list.add(
              _TodayItemCard(
                icon: Icons.fact_check_outlined,
                tone: _ItemTone.warning,
                title: 'Günün Yoklaması',
                subtitle:
                    '$unrecorded antrenman oturumunun yoklaması henüz alınmadı.',
                actionLabel: 'Yoklama Al',
                onTap: () => context.push('/operasyon/yoklama'),
              ),
            );
          }
        }
        break;
    }
    return list;
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.workspace});

  final ProWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions(context);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProSectionHeader(
          title: 'Hızlı İşlemler',
          subtitle: 'En sık kullanılan çalışma alanı aksiyonları',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions.take(4).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final list = <Widget>[
      _QuickActionButton(
        icon: Icons.calendar_month_outlined,
        label: 'Takvim',
        onTap: () => context.go('/takvim'),
      ),
      _QuickActionButton(
        icon: Icons.task_alt_outlined,
        label: 'Görevler',
        onTap: () => context.go('/gorevler'),
      ),
      _QuickActionButton(
        icon: Icons.inbox_outlined,
        label: 'Gelen Kutusu',
        onTap: () => context.go('/gelen-kutusu'),
      ),
    ];

    switch (workspace) {
      case ProWorkspace.club:
      case ProWorkspace.coaching:
        list.add(
          _QuickActionButton(
            icon: Icons.fact_check_outlined,
            label: 'Yoklama',
            onTap: () => context.push('/operasyon/yoklama'),
          ),
        );
        break;
      case ProWorkspace.accounting:
        list.add(
          _QuickActionButton(
            icon: Icons.account_balance_outlined,
            label: 'Banka',
            onTap: () => context.push('/operasyon/muhasebe/banka'),
          ),
        );
        break;
      case ProWorkspace.federation:
        list.add(
          _QuickActionButton(
            icon: Icons.newspaper_outlined,
            label: 'Bülten',
            onTap: () => context.push('/operasyon/bulten'),
          ),
        );
        break;
      case ProWorkspace.facility:
        list.add(
          _QuickActionButton(
            icon: Icons.sports_soccer_outlined,
            label: 'Sahalar',
            onTap: () => context.push('/operasyon/tesis/sahalar'),
          ),
        );
        break;
      case ProWorkspace.referee:
        list.add(
          _QuickActionButton(
            icon: Icons.sports_outlined,
            label: 'Atamalar',
            onTap: () => context.go('/gorevler'),
          ),
        );
        break;
      case ProWorkspace.platform:
        list.add(
          _QuickActionButton(
            icon: Icons.tune_outlined,
            label: 'Ayarlar',
            onTap: () => context.push('/operasyon/platform/yapilandirma'),
          ),
        );
        break;
    }
    return list;
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ProTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ProTheme.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: ProTheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: ProTheme.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ItemTone { neutral, info, warning, danger }

class _TodayItemCard extends StatelessWidget {
  const _TodayItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    this.tone = _ItemTone.neutral,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final _ItemTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = switch (tone) {
      _ItemTone.neutral => ProTheme.muted,
      _ItemTone.info => ProTheme.primary,
      _ItemTone.warning => const Color(0xFFF59E0B),
      _ItemTone.danger => const Color(0xFFF87171),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ProTheme.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ProTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(48, 48),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel,
                  style: const TextStyle(
                    color: ProTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: ProTheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSecurityFooter extends StatelessWidget {
  const _CompactSecurityFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ProTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ProTheme.line.withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined,
              size: 16, color: ProTheme.secondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Yetki sınırların aktif: Veri ve işlem izinleri sunucudaki RLS ve RPC kurallarıyla korunur.',
              style: TextStyle(
                color: ProTheme.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
