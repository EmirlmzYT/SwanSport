import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

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
    ..invalidate(drillDraftProvider);
}
