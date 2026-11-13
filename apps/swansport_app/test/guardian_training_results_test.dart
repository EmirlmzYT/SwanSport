import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/home/presentation/screens/guardian_home_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('guardian sees only shared coached training result',
      (tester) async {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    final request = (
      athleteId: 'athlete-1',
      from: to.subtract(const Duration(days: 89)),
      to: to,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => const ProfileInfo(id: 'guardian', fullName: 'Veli'),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(id: 'club-1', name: 'Swan Kulüp'),
          ),
          childrenOverviewProvider.overrideWith(
            (ref) async => const [
              ChildOverview(
                athleteId: 'athlete-1',
                name: 'Ada Sporcu',
                attendanceRate: 90,
                openFeeCount: 0,
                openFeeTotal: 0,
                healthStatus: 'fit',
                clubId: 'club-1',
                clubName: 'Swan Kulüp',
                branch: 'Yüzme',
              ),
            ],
          ),
          eventsProvider.overrideWith((ref) async => const []),
          announcementsProvider.overrideWith((ref) async => const []),
          trainingProgressProvider(request).overrideWith(
            (ref) async => [
              TrainingProgressEntry(
                sessionId: 'club-session',
                setNo: 1,
                sportCode: 'yuzme',
                sourceKind: 'club',
                clubId: 'club-1',
                clubName: 'Swan Kulüp',
                startedAt: to,
                archetype: 'lap_interval',
                workName: '50 m',
                comparisonKey: 'yuzme:club:club-1:lap_interval:50',
                primaryValue: 42000,
                unit: 'ms',
                sharedFeedback: 'Dönüş tekniği gelişti.',
              ),
              TrainingProgressEntry(
                sessionId: 'personal-session',
                setNo: 1,
                sportCode: 'yuzme',
                sourceKind: 'personal',
                startedAt: to,
                archetype: 'lap_interval',
                workName: '100 m',
                comparisonKey: 'yuzme:personal:personal:lap_interval:100',
                primaryValue: 90000,
                unit: 'ms',
                sharedFeedback: 'Görünmemeli',
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: GuardianHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paylaşılan antrenman sonucu'), findsOneWidget);
    expect(find.textContaining('Dönüş tekniği gelişti.'), findsOneWidget);
    expect(find.textContaining('Görünmemeli'), findsNothing);
    expect(find.textContaining('100 m'), findsNothing);
  });
}
