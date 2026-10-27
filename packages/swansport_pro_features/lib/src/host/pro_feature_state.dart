import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// Selected federation scope key (`federationId:sportCode:cityCode`).
final selectedFederationScopeKeyProvider = StateProvider<String?>(
  (ref) => null,
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
    ..invalidate(refereeReportDraftsProvider);
}
