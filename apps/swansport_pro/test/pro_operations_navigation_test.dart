import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_router.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  const club = ClubRef(
    id: 'club-1',
    name: 'Kulüp',
    role: 'club_admin',
  );

  testWidgets('club panel shows only flag-enabled operation entries',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'club_admin',
              coachLevel: 0,
              athleteKind: null,
            ),
          ),
          myClubsProvider.overrideWith((ref) async => const [club]),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.coachWorkspace,
              FeatureFlags.teamHub,
              FeatureFlags.attendanceOperations,
              FeatureFlags.sportTrainingSessions,
            }),
          ),
        ],
        child: const MaterialApp(home: ProDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Takımlar'), findsOneWidget);
    expect(find.text('Sporcu Kadrosu'), findsOneWidget);
    expect(find.text('Canlı Yoklama'), findsOneWidget);
    expect(find.text('Devam Geçmişi'), findsOneWidget);
    expect(find.text('Antrenman Şablonları'), findsOneWidget);
    expect(find.text('Antrenman Oturumu'), findsOneWidget);
  });

  testWidgets('typed Pro routes open shared team and attendance screens',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: 'club_admin',
            coachLevel: 0,
            athleteKind: null,
          ),
        ),
        myClubsProvider.overrideWith((ref) async => const [club]),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.coachWorkspace,
            FeatureFlags.teamHub,
            FeatureFlags.attendanceOperations,
            FeatureFlags.sportTrainingSessions,
          }),
        ),
        teamsProvider.overrideWith((ref) async => const []),
        eventsProvider.overrideWith((ref) async => const []),
        attendanceQueueProvider.overrideWith((ref) async => null),
        attendanceLocalDataProvider.overrideWith(
          (ref) => Stream.value(
            const {'cache': [], 'drafts': [], 'ops': []},
          ),
        ),
        myLiveSessionProvider.overrideWith((ref) async => null),
        myTrainingHistoryProvider.overrideWith((ref) async => const []),
        trainingProtocolsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedClubIdProvider.notifier).state = club.id;
    final router = container.read(proRouterProvider);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/operasyon/takimlar');
    await tester.pumpAndSettle();
    expect(find.byType(SharedTeamDirectoryScreen), findsOneWidget);
    expect(
        find.text('Henüz oluşturulmuş bir takım bulunmuyor.'), findsOneWidget);

    router.go('/operasyon/yoklama');
    await tester.pumpAndSettle();
    expect(find.byType(SharedLiveAttendanceScreen), findsOneWidget);
    expect(find.textContaining('Etkinlik yüklenemedi'), findsOneWidget);
    expect(find.text('Takvimi aç'), findsNothing);

    router.go('/operasyon/takim/team-1');
    await tester.pumpAndSettle();
    expect(find.byType(SharedTeamRosterScreen), findsOneWidget);
    expect(find.text('Kadro boş. Kulüp sporcularından ekleyebilirsin.'),
        findsOneWidget);

    router.go('/operasyon/antrenmanlar');
    await tester.pumpAndSettle();
    expect(find.byType(SharedTrainingListScreen), findsOneWidget);
    expect(find.text('Henüz antrenman kaydı yok.'), findsOneWidget);

    router.go('/operasyon/antrenman-sablonlari');
    await tester.pumpAndSettle();
    expect(find.byType(SharedProtocolListScreen), findsOneWidget);
    expect(find.text('Kullanılabilir şablon bulunamadı.'), findsOneWidget);
  });
}
