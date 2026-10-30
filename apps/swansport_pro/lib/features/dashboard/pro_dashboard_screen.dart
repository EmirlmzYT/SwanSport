import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../app/pro_router.dart';
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
                  refreshProWorkspaceData(ref, workspace);
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
    final itemsAsync = _buildTodayItemsAsync(context, ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProSectionHeader(
          title: 'Bugün',
          subtitle: 'En önemli operasyonel durumlar',
        ),
        const SizedBox(height: 10),
        itemsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: ProLoadingState(message: 'Operasyon verileri yükleniyor…'),
          ),
          error: (err, _) => ProErrorState(
            message: classifyOperationError(err).userMessage,
            onRetry: () => refreshProWorkspaceData(ref, workspace),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ProTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ProTheme.line),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: ProTheme.secondary,
                      size: 22,
                    ),
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
              );
            }
            return Column(
              children: items
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: item,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  AsyncValue<List<Widget>> _buildTodayItemsAsync(
    BuildContext context,
    WidgetRef ref,
  ) {
    switch (workspace) {
      case ProWorkspace.referee:
        final matchesAsync = ref.watch(refereeDutyMatchesProvider);
        if (matchesAsync.isLoading) return const AsyncValue.loading();
        if (matchesAsync.hasError) {
          return AsyncValue.error(
            matchesAsync.error!,
            matchesAsync.stackTrace!,
          );
        }
        final matches = matchesAsync.value ?? const [];
        final list = <Widget>[];
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
              onTap: () => context.go(ProRoutes.tasks),
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
              onTap: () => context.go(ProRoutes.calendar),
            ),
          );
        }
        return AsyncValue.data(list);

      case ProWorkspace.accounting:
        final summaryAsync = ref.watch(financeOperationsSummaryProvider);
        if (summaryAsync.isLoading) return const AsyncValue.loading();
        if (summaryAsync.hasError) {
          return AsyncValue.error(
            summaryAsync.error!,
            summaryAsync.stackTrace!,
          );
        }
        final summary = summaryAsync.value;
        final list = <Widget>[];
        if (summary != null && summary.pendingApprovalCount > 0) {
          list.add(
            _TodayItemCard(
              icon: Icons.pending_actions_outlined,
              tone: _ItemTone.warning,
              title: 'Onay Bekleyen Harcamalar',
              subtitle:
                  '${summary.pendingApprovalCount} gider onayı inceleme bekliyor.',
              actionLabel: 'İncele',
              onTap: () => context.push(ProRoutes.accounting),
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
              onTap: () => context.push(ProRoutes.bankReconciliation),
            ),
          );
        }
        return AsyncValue.data(list);

      case ProWorkspace.federation:
        final scopesAsync = ref.watch(federationConsoleScopesProvider);
        if (scopesAsync.isLoading && !scopesAsync.hasValue) {
          return const AsyncValue.loading();
        }
        if (scopesAsync.hasError && !scopesAsync.hasValue) {
          return AsyncValue.error(
            scopesAsync.error!,
            scopesAsync.stackTrace!,
          );
        }
        final scopes = resolveEffectiveFederationScopes(
          scopesAsync.value ?? const [],
          ref.watch(swanAccessProvider),
        );
        final selectedKey = ref.watch(selectedFederationScopeKeyProvider);
        final selectedScope = scopes
                .where((item) => federationScopeKey(item) == selectedKey)
                .firstOrNull ??
            scopes.firstOrNull;
        if (selectedScope == null) {
          return const AsyncValue.data(<Widget>[]);
        }
        final pendingQuery = (
          federationId: selectedScope.federationId,
          sportCode: selectedScope.sportCode,
          cityCode: selectedScope.cityCode,
          offset: 0,
        );
        final pendingAsync =
            ref.watch(federationScopedPendingResultsProvider(pendingQuery));
        if (pendingAsync.isLoading) return const AsyncValue.loading();
        if (pendingAsync.hasError) {
          return AsyncValue.error(
            pendingAsync.error!,
            pendingAsync.stackTrace!,
          );
        }
        final pending = pendingAsync.value ?? const [];
        final list = <Widget>[];
        if (pending.isNotEmpty) {
          list.add(
            _TodayItemCard(
              icon: Icons.how_to_reg_outlined,
              tone: _ItemTone.warning,
              title: 'Sonuç & Atama Bekleyenler',
              subtitle:
                  '${pending.length} müsabaka sonuç girişi veya hakem ataması bekliyor.',
              actionLabel: 'İncele',
              onTap: () => context.go(ProRoutes.tasks),
            ),
          );
        }
        return AsyncValue.data(list);

      case ProWorkspace.facility:
        final dutiesAsync = ref.watch(turfDutiesProvider(0));
        if (dutiesAsync.isLoading) return const AsyncValue.loading();
        if (dutiesAsync.hasError) {
          return AsyncValue.error(
            dutiesAsync.error!,
            dutiesAsync.stackTrace!,
          );
        }
        final duties = dutiesAsync.value?.items ?? const [];
        final list = <Widget>[];
        if (duties.isNotEmpty) {
          list.add(
            _TodayItemCard(
              icon: Icons.stadium_outlined,
              tone: _ItemTone.info,
              title: 'Tesis Görevleri',
              subtitle: '${duties.length} saha ve bakım operasyonu planlandı.',
              actionLabel: 'Görevler',
              onTap: () => context.go(ProRoutes.tasks),
            ),
          );
        }
        return AsyncValue.data(list);

      case ProWorkspace.platform:
        final waitlistAsync = ref.watch(launchWaitlistSummaryProvider);
        if (waitlistAsync.isLoading) return const AsyncValue.loading();
        if (waitlistAsync.hasError) {
          return AsyncValue.error(
            waitlistAsync.error!,
            waitlistAsync.stackTrace!,
          );
        }
        final waitlist = waitlistAsync.value;
        final list = <Widget>[];
        if (waitlist != null && waitlist.totalCount > 0) {
          list.add(
            _TodayItemCard(
              icon: Icons.people_outline_rounded,
              tone: _ItemTone.warning,
              title: 'Bekleme Listesi',
              subtitle:
                  '${waitlist.totalCount} başvuru onay ve inceleme bekliyor.',
              actionLabel: 'İncele',
              onTap: () => context.push(ProRoutes.platformWaitlist),
            ),
          );
        }
        return AsyncValue.data(list);

      case ProWorkspace.club:
      case ProWorkspace.coaching:
        final attendanceAsync = ref.watch(clubTodayAttendanceProvider);
        if (attendanceAsync.isLoading) return const AsyncValue.loading();
        if (attendanceAsync.hasError) {
          return AsyncValue.error(
            attendanceAsync.error!,
            attendanceAsync.stackTrace ?? StackTrace.current,
          );
        }
        final todayAttendance = attendanceAsync.valueOrNull;
        final list = <Widget>[];
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
                onTap: () => context.push(ProRoutes.attendance),
              ),
            );
          }
        }
        return AsyncValue.data(list);
    }
  }
}

class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow({required this.workspace});

  final ProWorkspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _buildActions(context, ref);
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

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    final list = <Widget>[];

    switch (workspace) {
      case ProWorkspace.club:
      case ProWorkspace.coaching:
        final flags = ref.watch(featureFlagsProvider).valueOrNull ??
            const FeatureFlags({});
        if (flags.has(FeatureFlags.attendanceOperations)) {
          list.addAll([
            _QuickActionButton(
              icon: Icons.fact_check_outlined,
              label: 'Yoklama Al',
              onTap: () => context.push(ProRoutes.attendance),
            ),
            _QuickActionButton(
              icon: Icons.history_edu_outlined,
              label: 'Devam Takibi',
              onTap: () => context.push(ProRoutes.attendanceHistory),
            ),
          ]);
        }
        break;
      case ProWorkspace.accounting:
        list.addAll([
          _QuickActionButton(
            icon: Icons.verified_outlined,
            label: 'Harcama Onayı',
            onTap: () => context.push(ProRoutes.accounting),
          ),
          _QuickActionButton(
            icon: Icons.account_balance_outlined,
            label: 'Banka Mutabakatı',
            onTap: () => context.push(ProRoutes.bankReconciliation),
          ),
          _QuickActionButton(
            icon: Icons.receipt_long_outlined,
            label: 'Finans Defteri',
            onTap: () => context.push(ProRoutes.accountingLedger),
          ),
        ]);
        break;
      case ProWorkspace.federation:
        list.addAll([
          _QuickActionButton(
            icon: Icons.newspaper_outlined,
            label: 'Bülten',
            onTap: () => context.push(ProRoutes.federationBulletin),
          ),
          _QuickActionButton(
            icon: Icons.leaderboard_outlined,
            label: 'Puan Durumu',
            onTap: () => context.push(ProRoutes.leagueStandings),
          ),
        ]);
        break;
      case ProWorkspace.facility:
        list.addAll([
          _QuickActionButton(
            icon: Icons.sports_soccer_outlined,
            label: 'Saha Durumu',
            onTap: () => context.push(ProRoutes.facility),
          ),
          _QuickActionButton(
            icon: Icons.build_circle_outlined,
            label: 'Tesis Görevleri',
            onTap: () => context.push(ProRoutes.facilityDuties),
          ),
        ]);
        break;
      case ProWorkspace.referee:
        list.addAll([
          _QuickActionButton(
            icon: Icons.assignment_turned_in_outlined,
            label: 'Hakem Görevleri',
            onTap: () => context.push(ProRoutes.refereeDuties),
          ),
          _QuickActionButton(
            icon: Icons.sports_outlined,
            label: 'Görev Programı',
            onTap: () => context.go(ProRoutes.calendar),
          ),
        ]);
        break;
      case ProWorkspace.platform:
        list.addAll([
          _QuickActionButton(
            icon: Icons.tune_outlined,
            label: 'Sistem Durumu',
            onTap: () => context.push(ProRoutes.platformStatus),
          ),
          _QuickActionButton(
            icon: Icons.people_outline_rounded,
            label: 'Bekleme Listesi',
            onTap: () => context.push(ProRoutes.platformWaitlist),
          ),
        ]);
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
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
            maxWidth: 240,
          ),
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ProTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 460 ||
              MediaQuery.textScalerOf(context).scale(14) >= 18;
          final leading = Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          );
          final details = Column(
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
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ProTheme.muted,
                  fontSize: 12,
                ),
              ),
            ],
          );
          final action = TextButton.icon(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(48, 48),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: ProTheme.primary,
            ),
            label: Text(
              actionLabel,
              style: const TextStyle(
                color: ProTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 8),
              action,
            ],
          );
        },
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
