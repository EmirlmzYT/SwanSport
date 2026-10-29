import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../workspaces/pro_workspace.dart';
import '../../workspaces/pro_workspace_controller.dart';

/// Aktif çalışma alanına göre gerçekten bekleyen operasyonel işlerin sayısı.
/// Sahte sayı üretmez; veri yoksa veya 0 ise 0 döner.
final proPendingTasksCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final workspace = ref.watch(selectedProWorkspaceProvider);
  if (workspace == null) return 0;

  try {
    switch (workspace) {
      case ProWorkspace.referee:
        final matches = (ref.watch(refereeDutyMatchesProvider).valueOrNull ??
                await ref.watch(refereeDutyMatchesProvider.future)) ??
            const [];
        return matches
            .where(
              (m) =>
                  m.matchStatus == 'scheduled' &&
                  m.status == MatchOfficialStatus.assigned,
            )
            .length;

      case ProWorkspace.accounting:
        final summary =
            ref.watch(financeOperationsSummaryProvider).valueOrNull ??
                await ref.watch(financeOperationsSummaryProvider.future);
        if (summary == null) return 0;
        return summary.pendingApprovalCount + summary.bankUnmatchedCount;

      case ProWorkspace.club:
      case ProWorkspace.coaching:
        final todayAttendance =
            ref.watch(clubTodayAttendanceProvider).valueOrNull;
        final unrecorded = todayAttendance != null
            ? (todayAttendance.trainingCount - todayAttendance.markedCount)
                .clamp(0, 999)
            : 0;
        return unrecorded;

      case ProWorkspace.facility:
        final duties = ref.watch(turfDutiesProvider(0)).valueOrNull ??
            await ref.watch(turfDutiesProvider(0).future);
        return duties?.items.length ?? 0;

      case ProWorkspace.platform:
        final waitlist = ref.watch(launchWaitlistSummaryProvider).valueOrNull ??
            await ref.watch(launchWaitlistSummaryProvider.future);
        return waitlist?.totalCount ?? 0;

      case ProWorkspace.federation:
        final scopesList =
            (ref.watch(federationConsoleScopesProvider).valueOrNull ??
                    await ref.watch(federationConsoleScopesProvider.future)) ??
                const [];
        final scopes = resolveEffectiveFederationScopes(
          scopesList,
          ref.watch(swanAccessProvider),
        );
        final selectedKey = ref.watch(selectedFederationScopeKeyProvider);
        final selectedScope = scopes
                .where((item) => federationScopeKey(item) == selectedKey)
                .firstOrNull ??
            scopes.firstOrNull;
        if (selectedScope == null) return 0;

        final pendingQuery = (
          federationId: selectedScope.federationId,
          sportCode: selectedScope.sportCode,
          cityCode: selectedScope.cityCode,
          offset: 0,
        );
        final pending = ref
                .watch(federationScopedPendingResultsProvider(pendingQuery))
                .valueOrNull ??
            await ref.watch(
              federationScopedPendingResultsProvider(pendingQuery).future,
            );
        return pending?.length ?? 0;
    }
  } catch (_) {
    return 0;
  }
});

/// Her çalışma alanına özgü operasyonel verileri yeniler.
void refreshProWorkspaceData(WidgetRef ref, ProWorkspace workspace) {
  switch (workspace) {
    case ProWorkspace.referee:
      ref.invalidate(refereeDutyMatchesProvider);
      break;
    case ProWorkspace.accounting:
      ref.invalidate(financeOperationsSummaryProvider);
      break;
    case ProWorkspace.club:
    case ProWorkspace.coaching:
      ref.invalidate(clubTodayAttendanceProvider);
      ref.invalidate(activeClubProvider);
      break;
    case ProWorkspace.federation:
      ref.invalidate(federationScopedPendingResultsProvider);
      ref.invalidate(federationConsoleScopesProvider);
      break;
    case ProWorkspace.facility:
      ref.invalidate(turfDutiesProvider(0));
      break;
    case ProWorkspace.platform:
      ref.invalidate(launchWaitlistSummaryProvider);
      break;
  }
  ref.invalidate(proPendingTasksCountProvider);
}
