import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro/features/operations/pro_tasks_screen.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets(
      'Pro dashboard and tasks embed SharedFederationOperationsPanel in federation workspace',
      (tester) async {
    final now = DateTime.now().toUtc();
    final access = SwanAccess(
      isPlatformAdmin: false,
      clubRole: null,
      coachLevel: 0,
      athleteKind: null,
      federationRoles: [
        FederationRole(
          id: 'r1',
          federationId: 'fed-1',
          profileId: 'u1',
          role: FederationRoleKind.president,
          startsOn: now.subtract(const Duration(days: 5)),
          endsOn: now.add(const Duration(days: 30)),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(access),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.leagueStandings,
              FeatureFlags.federationBulletin,
            }),
          ),
          federationConsoleScopesProvider.overrideWith(
            (ref) async => const [
              FederationConsoleScope(
                federationId: 'fed-1',
                name: 'Türkiye Futbol Federasyonu',
                sportCode: 'futbol',
                role: 'president',
              ),
            ],
          ),
          federationConsoleMatchesProvider.overrideWith(
            (ref, query) async => FederationConsolePage<FederationConsoleMatch>(
              total: 3,
              rows: const [],
            ),
          ),
          federationScopedDisciplinaryReportsProvider.overrideWith(
            (ref, offset) async =>
                FederationConsolePage<FederationDisciplinaryReport>(
              total: 1,
              rows: const [],
            ),
          ),
          standingsLeaguesProvider.overrideWith((ref) async => const []),
          federationDisciplinaryBulletinProvider.overrideWith(
            (ref, filter) async => const [],
          ),
          federationNoticesProvider.overrideWith(
            (ref, filter) async => const [],
          ),
        ],
        child: const MaterialApp(home: ProDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SharedFederationOperationsPanel), findsOneWidget);
    expect(find.text('Federasyon Operasyonları'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(access),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.leagueStandings,
              FeatureFlags.federationBulletin,
            }),
          ),
          federationConsoleScopesProvider.overrideWith(
            (ref) async => const [
              FederationConsoleScope(
                federationId: 'fed-1',
                name: 'Türkiye Futbol Federasyonu',
                sportCode: 'futbol',
                role: 'president',
              ),
            ],
          ),
          federationConsoleMatchesProvider.overrideWith(
            (ref, query) async => FederationConsolePage<FederationConsoleMatch>(
              total: 3,
              rows: const [],
            ),
          ),
          federationScopedDisciplinaryReportsProvider.overrideWith(
            (ref, offset) async =>
                FederationConsolePage<FederationDisciplinaryReport>(
              total: 1,
              rows: const [],
            ),
          ),
          standingsLeaguesProvider.overrideWith((ref) async => const []),
          federationDisciplinaryBulletinProvider.overrideWith(
            (ref, filter) async => const [],
          ),
          federationNoticesProvider.overrideWith(
            (ref, filter) async => const [],
          ),
        ],
        child: const MaterialApp(home: ProTasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProTasksScreen), findsOneWidget);
    expect(find.text('Görevler & Aksiyon Kuyruğu'), findsOneWidget);
  });
}
