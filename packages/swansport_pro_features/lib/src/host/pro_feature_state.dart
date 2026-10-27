import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// Selected federation scope key (`federationId:sportCode:cityCode`).
final selectedFederationScopeKeyProvider = StateProvider<String?>(
  (ref) => null,
);

/// Selected accountant club ID in the accounting workspace.
final selectedAccountantClubIdProvider = StateProvider<String?>(
  (ref) => null,
);

/// Selected turf field or club facility scope ID in the facility workspace.
final selectedFacilityScopeIdProvider = StateProvider<String?>(
  (ref) => null,
);

/// In-memory store for uncertain/pending idempotent write operations,
/// isolated by `scopeKey` (e.g. `userId:workspace:clubId:action`).
/// Reusing the exact same `operationId` and `payload` prevents duplicate
/// server mutations on retry after an uncertain network failure.
@immutable
final class ProPendingOperationRecord {
  const ProPendingOperationRecord({
    required this.operationId,
    required this.payload,
  });

  final String operationId;
  final Map<String, Object?> payload;
}

@immutable
final class ProPendingOperationStore {
  const ProPendingOperationStore([this._records = const {}]);

  final Map<String, ProPendingOperationRecord> _records;

  ProPendingOperationRecord? operationFor(String scopeKey) {
    if (scopeKey.isEmpty) return null;
    return _records[scopeKey];
  }
}

final class ProPendingOperationsNotifier
    extends Notifier<ProPendingOperationStore> {
  @override
  ProPendingOperationStore build() => const ProPendingOperationStore();

  void saveOperation({
    required String scopeKey,
    required String operationId,
    required Map<String, Object?> payload,
  }) {
    if (scopeKey.isEmpty || operationId.isEmpty) return;
    final next = <String, ProPendingOperationRecord>{
      ...state._records,
      scopeKey: ProPendingOperationRecord(
        operationId: operationId,
        payload: Map.unmodifiable(payload),
      ),
    };
    state = ProPendingOperationStore(Map.unmodifiable(next));
  }

  void clearOperation(String scopeKey) {
    if (scopeKey.isEmpty || !state._records.containsKey(scopeKey)) return;
    final next = <String, ProPendingOperationRecord>{...state._records}
      ..remove(scopeKey);
    state = ProPendingOperationStore(Map.unmodifiable(next));
  }
}

final proPendingOperationsProvider =
    NotifierProvider<ProPendingOperationsNotifier, ProPendingOperationStore>(
  ProPendingOperationsNotifier.new,
);

/// In-memory referee report draft store isolated by `(userId, matchId)`.
@immutable
final class RefereeReportDraftStore {
  const RefereeReportDraftStore([this._drafts = const {}]);

  final Map<String, String> _drafts;

  static String _key(String userId, String matchId) => '$userId:$matchId';

  String? draftFor({required String userId, required String matchId}) {
    if (userId.isEmpty || matchId.isEmpty) return null;
    return _drafts[_key(userId, matchId)];
  }
}

final class RefereeReportDraftsNotifier
    extends Notifier<RefereeReportDraftStore> {
  @override
  RefereeReportDraftStore build() => const RefereeReportDraftStore();

  void saveDraft({
    required String userId,
    required String matchId,
    required String notes,
  }) {
    if (userId.isEmpty || matchId.isEmpty) return;
    final key = RefereeReportDraftStore._key(userId, matchId);
    final next = <String, String>{...state._drafts};
    if (notes.isEmpty) {
      next.remove(key);
    } else {
      next[key] = notes;
    }
    state = RefereeReportDraftStore(Map.unmodifiable(next));
  }

  void clearDraft({required String userId, required String matchId}) {
    saveDraft(userId: userId, matchId: matchId, notes: '');
  }
}

final refereeReportDraftsProvider =
    NotifierProvider<RefereeReportDraftsNotifier, RefereeReportDraftStore>(
  RefereeReportDraftsNotifier.new,
);

/// Auditable list of context-scoped state reset by host transitions.
const proFeatureInvalidationTargets = <String>[
  'selectedClubIdProvider',
  'activeClubProvider',
  'clubAthletesProvider',
  'clubMemberCandidatesProvider',
  'unlinkedAthletesProvider',
  'teamsProvider',
  'teamRosterProvider',
  'attendanceSummaryProvider',
  'attendanceQueueProvider',
  'attendanceLocalDataProvider',
  'selectedSportContextProvider',
  'activeClubSportsProvider',
  'trainingProtocolsProvider',
  'trainingSessionProvider',
  'myTrainingHistoryProvider',
  'myLiveSessionProvider',
  'structuredDrillDraftProvider',
  'drillDraftProvider',
  'selectedFederationScopeKeyProvider',
  'federationConsoleScopesProvider',
  'federationConsoleMatchesProvider',
  'federationAvailableRefereesProvider',
  'federationDisciplinaryReportsProvider',
  'federationLockedReportProvider',
  'standingsLeaguesProvider',
  'leagueStandingsProvider',
  'federationDisciplinaryBulletinProvider',
  'federationNoticesProvider',
  'myRefereeMatchesProvider',
  'refereeDutyMatchesProvider',
  'refereeTodayMatchesProvider',
  'refereeLineupCandidatesProvider',
  'refereeMatchStateProvider',
  'matchLineupApprovalsProvider',
  'acceptedMatchOfficialsProvider',
  'refereeReportDraftsProvider',
  'selectedAccountantClubIdProvider',
  'myAccountantClubIdsProvider',
  'financeOperationsSummaryProvider',
  'clubLedgerPageProvider',
  'cashAccountsProvider',
  'accountBalancesProvider',
  'expenseCategoriesProvider',
  'receivablesProvider',
  'vendorsProvider',
  'recurringExpensesProvider',
  'upcomingOccurrencesProvider',
  'approvalPoliciesProvider',
  'pendingApprovalsProvider',
  'bankImportsProvider',
  'bankTransactionsProvider',
  'bankMatchSuggestionsProvider',
  'budgetLinesProvider',
  'cashForecastProvider',
  'financePeriodsProvider',
  'financeAdjustmentsProvider',
  'candidateAdjustableEntriesProvider',
  'closedPeriodCandidatesPageProvider',
  'selectedFacilityScopeIdProvider',
  'myManagedTurfFieldIdsProvider',
  'delegatedTurfFieldIdsProvider',
  'turfFieldsProvider',
  'turfOccupancyGridProvider',
  'turfDutiesProvider',
  'facilitiesProvider',
  'facilityLoadProvider',
  'facilityScheduleProvider',
  'facilityReservationsProvider',
  'myClubOperationsAuthorityProvider',
  'clubInventoryBoardProvider',
  'clubHealthOperationsProvider',
  'clubSportingOverviewProvider',
  'clubOperationControllerProvider',
  'reportAthletesProvider',
  'developmentReportProvider',
  'platformConfigProvider',
  'platformPlansProvider',
  'platformAuditLogsProvider',
  'launchWaitlistSummaryProvider',
  'launchWaitlistEntriesProvider',
  'proPendingOperationsProvider',
];

void invalidateProFeatureState(WidgetRef ref) {
  ref
    ..invalidate(selectedClubIdProvider)
    ..invalidate(activeClubProvider)
    ..invalidate(clubAthletesProvider)
    ..invalidate(clubMemberCandidatesProvider)
    ..invalidate(unlinkedAthletesProvider)
    ..invalidate(teamsProvider)
    ..invalidate(teamRosterProvider)
    ..invalidate(attendanceSummaryProvider)
    ..invalidate(attendanceQueueProvider)
    ..invalidate(attendanceLocalDataProvider)
    ..invalidate(selectedSportContextProvider)
    ..invalidate(activeClubSportsProvider)
    ..invalidate(trainingProtocolsProvider)
    ..invalidate(trainingSessionProvider)
    ..invalidate(myTrainingHistoryProvider)
    ..invalidate(myLiveSessionProvider)
    ..invalidate(structuredDrillDraftProvider)
    ..invalidate(drillDraftProvider)
    ..invalidate(selectedFederationScopeKeyProvider)
    ..invalidate(federationConsoleScopesProvider)
    ..invalidate(federationConsoleMatchesProvider)
    ..invalidate(federationAvailableRefereesProvider)
    ..invalidate(federationDisciplinaryReportsProvider)
    ..invalidate(federationLockedReportProvider)
    ..invalidate(standingsLeaguesProvider)
    ..invalidate(leagueStandingsProvider)
    ..invalidate(federationDisciplinaryBulletinProvider)
    ..invalidate(federationNoticesProvider)
    ..invalidate(myRefereeMatchesProvider)
    ..invalidate(refereeDutyMatchesProvider)
    ..invalidate(refereeTodayMatchesProvider)
    ..invalidate(refereeLineupCandidatesProvider)
    ..invalidate(refereeMatchStateProvider)
    ..invalidate(matchLineupApprovalsProvider)
    ..invalidate(acceptedMatchOfficialsProvider)
    ..invalidate(refereeReportDraftsProvider)
    ..invalidate(selectedAccountantClubIdProvider)
    ..invalidate(myAccountantClubIdsProvider)
    ..invalidate(financeOperationsSummaryProvider)
    ..invalidate(clubLedgerPageProvider)
    ..invalidate(cashAccountsProvider)
    ..invalidate(accountBalancesProvider)
    ..invalidate(expenseCategoriesProvider)
    ..invalidate(receivablesProvider)
    ..invalidate(vendorsProvider)
    ..invalidate(recurringExpensesProvider)
    ..invalidate(upcomingOccurrencesProvider)
    ..invalidate(approvalPoliciesProvider)
    ..invalidate(pendingApprovalsProvider)
    ..invalidate(bankImportsProvider)
    ..invalidate(bankTransactionsProvider)
    ..invalidate(bankMatchSuggestionsProvider)
    ..invalidate(budgetLinesProvider)
    ..invalidate(cashForecastProvider)
    ..invalidate(financePeriodsProvider)
    ..invalidate(financeAdjustmentsProvider)
    ..invalidate(candidateAdjustableEntriesProvider)
    ..invalidate(closedPeriodCandidatesPageProvider)
    ..invalidate(selectedFacilityScopeIdProvider)
    ..invalidate(myManagedTurfFieldIdsProvider)
    ..invalidate(delegatedTurfFieldIdsProvider)
    ..invalidate(turfFieldsProvider)
    ..invalidate(turfOccupancyGridProvider)
    ..invalidate(turfDutiesProvider)
    ..invalidate(facilitiesProvider)
    ..invalidate(facilityLoadProvider)
    ..invalidate(facilityScheduleProvider)
    ..invalidate(facilityReservationsProvider)
    ..invalidate(myClubOperationsAuthorityProvider)
    ..invalidate(clubInventoryBoardProvider)
    ..invalidate(clubHealthOperationsProvider)
    ..invalidate(clubSportingOverviewProvider)
    ..invalidate(clubOperationControllerProvider)
    ..invalidate(reportAthletesProvider)
    ..invalidate(developmentReportProvider)
    ..invalidate(platformConfigProvider)
    ..invalidate(platformPlansProvider)
    ..invalidate(platformAuditLogsProvider)
    ..invalidate(launchWaitlistSummaryProvider)
    ..invalidate(launchWaitlistEntriesProvider)
    ..invalidate(proPendingOperationsProvider);
}
