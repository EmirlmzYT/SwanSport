import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('Pro panel embeds the shared Phase 2 operations panel',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 1,
              athleteKind: null,
            ),
          ),
          myClubsProvider.overrideWith(
            (ref) async => const [
              ClubRef(id: 'club-1', name: 'Kulüp', role: 'coach'),
            ],
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.coachWorkspace,
              FeatureFlags.teamHub,
              FeatureFlags.attendanceOperations,
              FeatureFlags.sportTrainingSessions,
            }),
          ),
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
        ],
        child: const MaterialApp(home: ProDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SharedClubOperationsPanel), findsOneWidget);
    expect(find.text('Kulüp Operasyonları'), findsOneWidget);
  });
}
