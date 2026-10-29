import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/clubs/presentation/club_cockpit_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('SwanSport cockpit embeds the shared Phase 2 panel once',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(),
        child: const MaterialApp(home: ClubCockpitScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SharedClubOperationsPanel), findsOneWidget);
    expect(find.text('Kulüp Operasyonları'), findsOneWidget);
    expect(find.text('Antrenman Şablonları & Oturumlar'), findsNothing);
  });
}

List<Override> _overrides() => [
      swanAccessProvider.overrideWithValue(
        const SwanAccess(
          isPlatformAdmin: false,
          clubRole: 'club_admin',
          coachLevel: 0,
          athleteKind: null,
        ),
      ),
      activeClubProvider.overrideWith(
        (ref) async => const ClubRef(
          id: 'club-1',
          name: 'Kulüp',
          role: 'club_admin',
        ),
      ),
      featureFlagsProvider.overrideWith(
        (ref) async => const FeatureFlags({
          FeatureFlags.coachWorkspace,
          FeatureFlags.teamHub,
          FeatureFlags.attendanceOperations,
          FeatureFlags.sportTrainingSessions,
        }),
      ),
      featureEnabledProvider(FeatureFlags.clubStaffOperations)
          .overrideWithValue(false),
      featureEnabledProvider(FeatureFlags.seasonSetup).overrideWithValue(false),
      clubPendingApplicationsProvider.overrideWith((ref) async => const []),
      clubAthletesProvider.overrideWith((ref) async => const []),
      pendingPaymentsProvider.overrideWith((ref) async => const []),
      teamsProvider.overrideWith((ref) async => const []),
      clubRosterCountsProvider.overrideWith(
        (ref) async => const ClubRosterCounts(total: 0, active: 0),
      ),
      clubTodayAttendanceProvider.overrideWith(
        (ref) async => const ClubTodayAttendance(
          trainingCount: 0,
          markedCount: 0,
        ),
      ),
      attendanceSummaryProvider.overrideWith((ref) async => const []),
      trainingProtocolsProvider.overrideWith((ref) async => const []),
      myLiveSessionProvider.overrideWith((ref) async => null),
    ];
