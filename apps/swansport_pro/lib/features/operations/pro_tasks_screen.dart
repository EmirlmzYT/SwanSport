import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/pro_router.dart';
import '../../app/pro_theme.dart';
import '../../widgets/pro_ui_components.dart';
import '../../workspaces/pro_workspace.dart';
import '../../workspaces/pro_workspace_controller.dart';
import 'pro_tasks_controller.dart';

enum _TasksFilter { all, pending, today, completed }

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
  _TasksFilter _filter = _TasksFilter.all;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    if (workspace == null) {
      return const Scaffold(
        body: Center(child: Text('Çalışma alanı bulunamadı.')),
      );
    }

    final tasks = _collectTasks(context, ref, workspace);
    final filteredTasks = _applyFilter(tasks, _filter);

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
                    ref.invalidate(proPendingTasksCountProvider);
                  },
                ),
              ),
              const SizedBox(height: 14),
              ProFilterBar(
                filters: const ['Tümü', 'Bekleyen', 'Bugün', 'Tamamlanan'],
                selected: switch (_filter) {
                  _TasksFilter.all => 'Tümü',
                  _TasksFilter.pending => 'Bekleyen',
                  _TasksFilter.today => 'Bugün',
                  _TasksFilter.completed => 'Tamamlanan',
                },
                onChanged: (val) {
                  setState(() {
                    _filter = switch (val) {
                      'Bekleyen' => _TasksFilter.pending,
                      'Bugün' => _TasksFilter.today,
                      'Tamamlanan' => _TasksFilter.completed,
                      _ => _TasksFilter.all,
                    };
                  });
                },
              ),
              const SizedBox(height: 18),
              if (filteredTasks.isEmpty)
                ProEmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'Bekleyen operasyon görevi bulunmuyor',
                  subtitle:
                      'Tüm görevler tamamlandı veya seçili filtreye uygun işlem yok.',
                  action: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => context.go('/takvim'),
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Takvimi Gör'),
                  ),
                )
              else ...[
                _buildSection(
                  title: 'Şimdi',
                  subtitle: 'Acil onaylar ve süresi dolmak üzere olan işlemler',
                  tasks: filteredTasks
                      .where((t) => t.priority == ProTaskPriority.now)
                      .toList(),
                ),
                _buildSection(
                  title: 'Bugün',
                  subtitle: 'Günün planlanmış operasyonel işleri',
                  tasks: filteredTasks
                      .where((t) => t.priority == ProTaskPriority.today)
                      .toList(),
                ),
                _buildSection(
                  title: 'Yaklaşan',
                  subtitle: 'Haftalık program ve yaklaşan incelemeler',
                  tasks: filteredTasks
                      .where((t) => t.priority == ProTaskPriority.upcoming)
                      .toList(),
                ),
                _buildSection(
                  title: 'Tamamlandı / Bilgi',
                  subtitle: 'Sonuçlanan görevler ve arşiv kayıtları',
                  tasks: filteredTasks
                      .where((t) => t.priority == ProTaskPriority.completed)
                      .toList(),
                ),
              ],
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

  List<ProTaskItem> _applyFilter(List<ProTaskItem> tasks, _TasksFilter filter) {
    switch (filter) {
      case _TasksFilter.all:
        return tasks;
      case _TasksFilter.pending:
        return tasks
            .where((t) =>
                t.priority == ProTaskPriority.now ||
                t.priority == ProTaskPriority.today)
            .toList();
      case _TasksFilter.today:
        return tasks.where((t) => t.priority == ProTaskPriority.today).toList();
      case _TasksFilter.completed:
        return tasks
            .where((t) => t.priority == ProTaskPriority.completed)
            .toList();
    }
  }

  List<ProTaskItem> _collectTasks(
    BuildContext context,
    WidgetRef ref,
    ProWorkspace workspace,
  ) {
    final list = <ProTaskItem>[];

    switch (workspace) {
      case ProWorkspace.referee:
        final matches =
            ref.watch(refereeDutyMatchesProvider).valueOrNull ?? const [];
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
        break;

      case ProWorkspace.accounting:
        final summary = ref.watch(financeOperationsSummaryProvider).valueOrNull;
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
        break;

      case ProWorkspace.club:
      case ProWorkspace.coaching:
        final todayAttendance =
            ref.watch(clubTodayAttendanceProvider).valueOrNull;
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
        break;

      case ProWorkspace.federation:
        final pending =
            ref.watch(federationPendingResultsProvider(0)).valueOrNull ??
                const [];
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
        break;

      case ProWorkspace.facility:
        final duties =
            ref.watch(turfDutiesProvider(0)).valueOrNull?.items ?? const [];
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
        break;

      case ProWorkspace.platform:
        final waitlist = ref.watch(launchWaitlistSummaryProvider).valueOrNull;
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
        break;
    }

    return list;
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
