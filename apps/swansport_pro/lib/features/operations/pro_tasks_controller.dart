import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../workspaces/pro_workspace.dart';
import '../../workspaces/pro_workspace_controller.dart';

/// Aktif çalışma alanına göre gerçekten bekleyen operasyonel işlerin sayısı.
/// Sahte sayı üretmez; veri yoksa veya 0 ise 0 döner.
final proPendingTasksCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final workspace = ref.watch(selectedProWorkspaceProvider);
  if (workspace == null) return 0;

  switch (workspace) {
    case ProWorkspace.referee:
      final matchesAsync = ref.watch(refereeDutyMatchesProvider);
      final matches = matchesAsync.valueOrNull ?? const [];
      return matches
          .where(
            (m) =>
                m.matchStatus == 'scheduled' &&
                m.status == MatchOfficialStatus.assigned,
          )
          .length;

    case ProWorkspace.accounting:
      final summaryAsync = ref.watch(financeOperationsSummaryProvider);
      final summary = summaryAsync.valueOrNull;
      if (summary == null) return 0;
      return summary.pendingApprovalCount + summary.bankUnmatchedCount;

    case ProWorkspace.club:
    case ProWorkspace.coaching:
      final pendingApps =
          ref.watch(clubPendingApplicationsProvider).valueOrNull ?? const [];
      final todayAttendance =
          ref.watch(clubTodayAttendanceProvider).valueOrNull;
      final unrecorded = todayAttendance != null
          ? (todayAttendance.trainingCount - todayAttendance.markedCount)
              .clamp(0, 999)
          : 0;
      return pendingApps.length + unrecorded;

    case ProWorkspace.facility:
      final duties = ref.watch(turfDutiesProvider(0)).valueOrNull;
      return duties?.items.length ?? 0;

    case ProWorkspace.platform:
      final waitlist = ref.watch(launchWaitlistSummaryProvider).valueOrNull;
      return waitlist?.totalCount ?? 0;

    case ProWorkspace.federation:
      final pending =
          ref.watch(federationPendingResultsProvider(0)).valueOrNull;
      return pending?.length ?? 0;
  }
});
