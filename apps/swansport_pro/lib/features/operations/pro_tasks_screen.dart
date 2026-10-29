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
import 'pro_tasks_controller.dart';

enum ProTaskPriority { now, today, upcoming, completed }

class ProTaskItem {
  const ProTaskItem({
    required this.id,
    required this.title,
    required this.context,
    required this.priority,
    required this.actionLabel,
    required this.onAction,
    this.status = 'Bekliyor',
    this.icon = Icons.task_alt_rounded,
  });

  final String id;
  final String title;
  final String context;
  final ProTaskPriority priority;
  final String actionLabel;
  final VoidCallback onAction;
  final String status;
  final IconData icon;
}

class ProTasksScreen extends ConsumerStatefulWidget {
  const ProTasksScreen({super.key});

  @override
  ConsumerState<ProTasksScreen> createState() => _ProTasksScreenState();
}

class _ProTasksScreenState extends ConsumerState<ProTasksScreen> {
  String _filter = 'Tümü';

  List<String> _buildAvailableFilters(List<ProTaskItem> tasks) {
    final filters = <String>['Tümü'];
    if (tasks.any((t) => t.priority == ProTaskPriority.now)) {
      filters.add('Bekleyen');
    }
    if (tasks.any((t) => t.priority == ProTaskPriority.today)) {
      filters.add('Bugün');
    }
    if (tasks.any((t) => t.priority == ProTaskPriority.upcoming)) {
      filters.add('Yaklaşan');
    }
    if (tasks.any((t) => t.priority == ProTaskPriority.completed)) {
      filters.add('Tamamlanan');
    }
    return filters;
  }

  List<ProTaskItem> _applyFilter(List<ProTaskItem> tasks, String filter) {
    switch (filter) {
      case 'Bekleyen':
        return tasks.where((t) => t.priority == ProTaskPriority.now).toList();
      case 'Bugün':
        return tasks.where((t) => t.priority == ProTaskPriority.today).toList();
      case 'Yaklaşan':
        return tasks
            .where((t) => t.priority == ProTaskPriority.upcoming)
            .toList();
      case 'Tamamlanan':
        return tasks
            .where((t) => t.priority == ProTaskPriority.completed)
            .toList();
      case 'Tümü':
      default:
        return tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    if (workspace == null) {
      return const Scaffold(
        body: Center(child: Text('Çalışma alanı bulunamadı.')),
      );
    }

    final tasksAsync = _collectTasksAsync(context, ref, workspace);

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            children: [
              ProPageHeader(
                title: 'Görevler & Aksiyon Kuyruğu',
                subtitle:
                    '${workspace.label} çalışma alanında bekleyen onaylar ve yapılması gerekenler',
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ProTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: ProTheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: ProTheme.primary,
                    size: 22,
                  ),
                ),
                action: IconButton(
                  icon:
                      const Icon(Icons.refresh_rounded, color: ProTheme.muted),
                  tooltip: 'Yenile',
                  onPressed: () {
                    refreshProWorkspaceData(ref, workspace);
                  },
                ),
              ),
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  final tasks = tasksAsync.valueOrNull ?? const [];
                  final availableFilters = _buildAvailableFilters(tasks);
                  final activeFilter =
                      availableFilters.contains(_filter) ? _filter : 'Tümü';
                  final filteredTasks = _applyFilter(tasks, activeFilter);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProFilterBar(
                        filters: availableFilters,
                        selected: activeFilter,
                        onChanged: (val) {
                          setState(() {
                            _filter = val;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      tasksAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => ProErrorState(
                          message: 'Görevler yüklenirken bir hata oluştu.',
                          onRetry: () =>
                              refreshProWorkspaceData(ref, workspace),
                        ),
                        data: (_) {
                          if (filteredTasks.isEmpty) {
                            return ProEmptyState(
                              icon: Icons.task_alt_rounded,
                              title: 'Bekleyen operasyon görevi bulunmuyor',
                              subtitle:
                                  'Tüm görevler tamamlandı veya seçili filtreye uygun işlem yok.',
                              action: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: () => context.go(ProRoutes.calendar),
                                icon: const Icon(Icons.calendar_month_outlined,
                                    size: 18),
                                label: const Text('Takvimi Gör'),
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSection(
                                title: 'Şimdi',
                                subtitle:
                                    'Acil onaylar ve süresi dolmak üzere olan işlemler',
                                tasks: filteredTasks
                                    .where((t) =>
                                        t.priority == ProTaskPriority.now)
                                    .toList(),
                              ),
                              _buildSection(
                                title: 'Bugün',
                                subtitle: 'Günün planlanmış operasyonel işleri',
                                tasks: filteredTasks
                                    .where((t) =>
                                        t.priority == ProTaskPriority.today)
                                    .toList(),
                              ),
                              _buildSection(
                                title: 'Yaklaşan',
                                subtitle:
                                    'Haftalık program ve yaklaşan incelemeler',
                                tasks: filteredTasks
                                    .where((t) =>
                                        t.priority == ProTaskPriority.upcoming)
                                    .toList(),
                              ),
                              _buildSection(
                                title: 'Tamamlandı / Bilgi',
                                subtitle:
                                    'Sonuçlanan görevler ve arşiv kayıtları',
                                tasks: filteredTasks
                                    .where((t) =>
                                        t.priority == ProTaskPriority.completed)
                                    .toList(),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required List<ProTaskItem> tasks,
  }) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProSectionHeader(
            title: title,
            subtitle: subtitle,
            count: tasks.length,
          ),
          const SizedBox(height: 10),
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskTile(task: task),
            ),
          ),
        ],
      ),
    );
  }

  AsyncValue<List<ProTaskItem>> _collectTasksAsync(
    BuildContext context,
    WidgetRef ref,
    ProWorkspace workspace,
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
        final list = <ProTaskItem>[];
        for (final m in matches) {
          if (m.matchStatus == 'scheduled' &&
              m.status == MatchOfficialStatus.assigned) {
            list.add(
              ProTaskItem(
                id: 'ref-assign-${m.matchId}',
                icon: Icons.assignment_late_outlined,
                title: 'Hakem Atama Onayı',
                context:
                    '${m.homeClubName ?? 'Ev Sahibi'} vs ${m.awayClubName ?? 'Deplasman'} • ${m.duty.name}',
                priority: ProTaskPriority.now,
                status: 'Yanıt Bekliyor',
                actionLabel: 'Yanıtla',
                onAction: () => context.push(ProRoutes.refereeDuties),
              ),
            );
          } else if (m.status == MatchOfficialStatus.accepted) {
            if (m.matchStatus == 'completed') {
              list.add(
                ProTaskItem(
                  id: 'ref-report-${m.matchId}',
                  icon: Icons.description_outlined,
                  title: 'Müsabaka Raporu',
                  context:
                      '${m.homeClubName ?? ''} vs ${m.awayClubName ?? ''} • Rapor Girişi',
                  priority: ProTaskPriority.now,
                  status: 'Rapor Bekliyor',
                  actionLabel: 'Rapor Yaz',
                  onAction: () =>
                      context.push(ProRoutes.refereeReport(m.matchId)),
                ),
              );
            } else if (m.matchStatus == 'scheduled') {
              list.add(
                ProTaskItem(
                  id: 'ref-match-${m.matchId}',
                  icon: Icons.sports_rounded,
                  title: 'Müsabaka Görevi',
                  context:
                      '${m.location ?? 'Tesis'} • ${m.homeClubName ?? ''} vs ${m.awayClubName ?? ''}',
                  priority: ProTaskPriority.today,
                  status: 'Kabul Edildi',
                  actionLabel: 'Takvim',
                  onAction: () => context.go(ProRoutes.calendar),
                ),
              );
            }
          }
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
        final list = <ProTaskItem>[];
        if (summary != null) {
          if (summary.pendingApprovalCount > 0) {
            list.add(
              ProTaskItem(
                id: 'acc-approvals',
                icon: Icons.pending_actions_outlined,
                title: 'Bekleyen Harcama Onayları',
                context:
                    '${summary.pendingApprovalCount} adet gider belgesi inceleme bekliyor',
                priority: ProTaskPriority.now,
                status: 'Onay Bekliyor',
                actionLabel: 'İncele',
                onAction: () => context.push(ProRoutes.accounting),
              ),
            );
          }
          if (summary.bankUnmatchedCount > 0) {
            list.add(
              ProTaskItem(
                id: 'acc-bank',
                icon: Icons.account_balance_wallet_outlined,
                title: 'Banka Mutabakatı',
                context:
                    '${summary.bankUnmatchedCount} hareket eşleştirilmeyi bekliyor',
                priority: ProTaskPriority.today,
                status: 'Eşleşme Bekliyor',
                actionLabel: 'Eşleştir',
                onAction: () => context.push(ProRoutes.bankReconciliation),
              ),
            );
          }
        }
        return AsyncValue.data(list);

      case ProWorkspace.club:
      case ProWorkspace.coaching:
        final attendanceAsync = ref.watch(clubTodayAttendanceProvider);
        if (attendanceAsync.isLoading) return const AsyncValue.loading();
        final todayAttendance = attendanceAsync.valueOrNull;
        final list = <ProTaskItem>[];
        if (todayAttendance != null) {
          final unrecorded =
              (todayAttendance.trainingCount - todayAttendance.markedCount)
                  .clamp(0, 999);
          if (unrecorded > 0) {
            list.add(
              ProTaskItem(
                id: 'club-attendance',
                icon: Icons.fact_check_outlined,
                title: 'Günün Antrenman Yoklaması',
                context:
                    '$unrecorded antrenman oturumunun yoklaması henüz sisteme girilmedi',
                priority: ProTaskPriority.today,
                status: 'Yoklama Eksik',
                actionLabel: 'Yoklama Al',
                onAction: () => context.push(ProRoutes.attendance),
              ),
            );
          }
        }
        return AsyncValue.data(list);

      case ProWorkspace.federation:
        final scopesAsync = ref.watch(federationConsoleScopesProvider);
        if (scopesAsync.isLoading) return const AsyncValue.loading();
        if (scopesAsync.hasError) {
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
          return const AsyncValue.data(<ProTaskItem>[]);
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
        final list = <ProTaskItem>[];
        if (pending.isNotEmpty) {
          list.add(
            ProTaskItem(
              id: 'fed-pending',
              icon: Icons.how_to_reg_outlined,
              title: 'Müsabaka Sonuç ve Hakem Onayları',
              context:
                  '${pending.length} müsabaka sonuç onayı veya hakem ataması bekliyor',
              priority: ProTaskPriority.now,
              status: 'İşlem Bekliyor',
              actionLabel: 'İncele',
              onAction: () => context.push(ProRoutes.federationBulletin),
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
        final list = <ProTaskItem>[];
        for (final duty in duties) {
          list.add(
            ProTaskItem(
              id: 'fac-duty-${duty.id}',
              icon: Icons.stadium_outlined,
              title: '${duty.fieldName} (${duty.venueName})',
              context: duty.label,
              priority: ProTaskPriority.today,
              status: duty.status,
              actionLabel: 'İncele',
              onAction: () => context.push(ProRoutes.facilityDuties),
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
        final list = <ProTaskItem>[];
        if (waitlist != null && waitlist.totalCount > 0) {
          list.add(
            ProTaskItem(
              id: 'plat-waitlist',
              icon: Icons.people_outline_rounded,
              title: 'Bekleme Listesi Başvuruları',
              context:
                  '${waitlist.totalCount} yeni kulüp/organizatör başvurusu incelenmeyi bekliyor',
              priority: ProTaskPriority.now,
              status: 'İnceleme Bekliyor',
              actionLabel: 'İncele',
              onAction: () => context.push(ProRoutes.platformWaitlist),
            ),
          );
        }
        return AsyncValue.data(list);
    }
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final ProTaskItem task;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (task.priority) {
      ProTaskPriority.now => const Color(0xFFEF4444),
      ProTaskPriority.today => const Color(0xFFF59E0B),
      ProTaskPriority.upcoming => ProTheme.primary,
      ProTaskPriority.completed => const Color(0xFF10B981),
    };

    final badgeTone = switch (task.priority) {
      ProTaskPriority.now => ProStatusTone.urgent,
      ProTaskPriority.today => ProStatusTone.pending,
      ProTaskPriority.upcoming => ProStatusTone.scheduled,
      ProTaskPriority.completed => ProStatusTone.completed,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(task.icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: ProTheme.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ProStatusBadge(label: task.status, tone: badgeTone),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  task.context,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: ProTheme.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ProTheme.primary,
              foregroundColor: const Color(0xFF07111F),
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: task.onAction,
            child: Text(
              task.actionLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
