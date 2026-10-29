import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/pro_operations/swan_pro_feature_host.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets(
    'SwanProFeatureHost embeds SharedFederationOperationsPanel and SharedRefereeOperationsPanel with SwanSport route parity',
    (tester) async {
      final now = DateTime.now().toUtc();
      final pushedRoutes = <String>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(
              SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                federationRoles: [
                  FederationRole(
                    id: 'r-pres',
                    federationId: 'fed-tff',
                    profileId: 'u-pres',
                    role: FederationRoleKind.president,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
                refereeProfile: const RefereeProfile(
                  id: 'ref-1',
                  profileId: 'u-pres',
                  licenseNumber: 'TFF-01',
                  badgeTier: RefereeBadgeTier.national,
                  sportCode: 'futbol',
                  cityCode: '06',
                  isActive: true,
                ),
              ),
            ),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.leagueStandings,
                FeatureFlags.federationBulletin,
                FeatureFlags.refereeCockpit,
              }),
            ),
            federationConsoleScopesProvider.overrideWith(
              (ref) async => const [
                FederationConsoleScope(
                  federationId: 'fed-tff',
                  name: 'Türkiye Futbol Federasyonu',
                  sportCode: 'futbol',
                  role: 'president',
                ),
              ],
            ),
            federationConsoleMatchesProvider.overrideWith(
              (ref, query) async =>
                  FederationConsolePage<FederationConsoleMatch>(
                total: 2,
                rows: const [],
              ),
            ),
            federationScopedDisciplinaryReportsProvider.overrideWith(
              (ref, offset) async =>
                  FederationConsolePage<FederationDisciplinaryReport>(
                total: 0,
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
            refereeDutyMatchesProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name != null && settings.name != '/') {
                pushedRoutes.add(settings.name!);
              }
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(
                  body: SwanProFeatureHost(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SharedFederationOperationsPanel(),
                          SizedBox(height: 16),
                          SharedRefereeOperationsPanel(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SharedFederationOperationsPanel), findsOneWidget);
      expect(find.byType(SharedRefereeOperationsPanel), findsOneWidget);

      await tester.tap(find.text('Resmî Müsabakalar & Takvim'));
      await tester.pumpAndSettle();
      expect(pushedRoutes, contains('/federasyon-merkezi'));
    },
  );
}
