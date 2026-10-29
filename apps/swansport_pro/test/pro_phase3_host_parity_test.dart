import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro/features/operations/pro_tasks_screen.dart';
import 'package:swansport_pro/workspaces/pro_workspace.dart';
import 'package:swansport_pro/workspaces/pro_workspace_controller.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets(
    'Pro dashboard and tasks embed SharedRefereeOperationsPanel in referee workspace and isolate state across workspaces',
    (tester) async {
      final now = DateTime.now().toUtc();
      const matchId = '44444444-4444-4444-8444-444444444444';

      tester.view.physicalSize = const Size(1024, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
                    profileId: 'u-dual',
                    role: FederationRoleKind.president,
                    startsOn: now.subtract(const Duration(days: 5)),
                    endsOn: now.add(const Duration(days: 30)),
                  ),
                ],
                refereeProfile: const RefereeProfile(
                  id: 'ref-1',
                  profileId: 'u-dual',
                  licenseNumber: 'TFF-06-01',
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
                total: 3,
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
            refereeDutyMatchesProvider.overrideWith(
              (ref) async => [
                RefereeMatchSummary(
                  officialId: 'off-1',
                  matchId: matchId,
                  duty: MatchOfficialDuty.headReferee,
                  status: MatchOfficialStatus.accepted,
                  assignedAt: now.subtract(const Duration(hours: 6)),
                  startsAt: now,
                  sportCode: 'futbol',
                  homeClubName: 'Anadolu SK',
                  awayClubName: 'Başkent SK',
                  matchStatus: 'scheduled',
                  cityCode: '06',
                ),
              ],
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              return MaterialApp(
                home: Column(
                  children: [
                    TextButton(
                      key: const Key('switch-to-referee'),
                      onPressed: () {
                        invalidateProFeatureState(ref);
                        ref
                            .read(selectedProWorkspaceProvider.notifier)
                            .selectWorkspace(ProWorkspace.referee);
                      },
                      child: const Text('Hakemlik'),
                    ),
                    const Expanded(child: ProDashboardScreen()),
                    const Expanded(child: ProTasksScreen()),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default workspace by priority for federation+referee is Federation
      expect(find.byType(SharedFederationOperationsPanel), findsOneWidget);
      expect(find.byType(ProTasksScreen), findsOneWidget);

      // Save a referee draft and switch workspace -> invalidateProFeatureState clears drafts
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProDashboardScreen)),
      );
      container.read(refereeReportDraftsProvider.notifier).saveDraft(
            userId: 'u-dual',
            matchId: matchId,
            notes: 'Geçici taslak',
          );
      expect(
        container
            .read(refereeReportDraftsProvider)
            .draftFor(userId: 'u-dual', matchId: matchId),
        'Geçici taslak',
      );

      await tester.tap(find.byKey(const Key('switch-to-referee')));
      await tester.pumpAndSettle();

      expect(find.byType(SharedRefereeOperationsPanel), findsOneWidget);
      expect(
        container
            .read(refereeReportDraftsProvider)
            .draftFor(userId: 'u-dual', matchId: matchId),
        isNull,
      );
    },
  );
}
