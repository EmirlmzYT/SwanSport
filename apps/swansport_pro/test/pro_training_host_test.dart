import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro/features/operations/pro_club_context_selector.dart';

void main() {
  const access = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'coach',
    coachLevel: 1,
    athleteKind: null,
  );
  const club = ClubRef(id: 'club-1', name: 'Kulüp', role: 'coach');

  testWidgets('Pro training entry requires both rollout flags', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(access),
          myClubsProvider.overrideWith((ref) async => const [club]),
          proAuthorizedClubsProvider.overrideWithValue(
            const AsyncData([club]),
          ),
          activeClubProvider.overrideWith((ref) async => club),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.sportTrainingSessions,
            }),
          ),
        ],
        child: const MaterialApp(home: ProDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Operasyonlar kademeli yayında'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Antrenman Şablonları'), findsNothing);
    expect(find.text('Operasyonlar kademeli yayında'), findsOneWidget);
  });

  testWidgets('Pro training entry opens when both flags are enabled',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(access),
          myClubsProvider.overrideWith((ref) async => const [club]),
          proAuthorizedClubsProvider.overrideWithValue(
            const AsyncData([club]),
          ),
          activeClubProvider.overrideWith((ref) async => club),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.coachWorkspace,
              FeatureFlags.sportTrainingSessions,
            }),
          ),
        ],
        child: const MaterialApp(home: ProDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Antrenman Şablonları'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Antrenman Şablonları'), findsOneWidget);
  });
}
