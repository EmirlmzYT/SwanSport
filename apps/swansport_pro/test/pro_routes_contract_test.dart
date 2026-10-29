import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_router.dart';
import 'package:swansport_pro/features/operations/pro_club_context_selector.dart';
import 'package:swansport_pro/features/operations/pro_tasks_controller.dart';
import 'package:swansport_pro/features/operations/pro_tasks_screen.dart';
import 'package:swansport_pro/widgets/pro_ui_components.dart';
import 'package:swansport_pro/workspaces/pro_workspace.dart';
import 'package:swansport_pro/workspaces/pro_workspace_controller.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

Session _makeSession(String userId) {
  return Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-26',
      email: '$userId@swansport.com',
    ),
  );
}

Set<String> _extractRegisteredRoutes(GoRouter router) {
  final paths = <String>{};
  void collect(RouteBase r) {
    if (r is GoRoute) {
      paths.add(r.path);
    } else if (r is ShellRoute) {
      for (final child in r.routes) {
        collect(child);
      }
    } else if (r is StatefulShellRoute) {
      for (final b in r.branches) {
        for (final child in b.routes) {
          collect(child);
        }
      }
    }
  }

  for (final r in router.configuration.routes) {
    collect(r);
  }
  return paths;
}

bool _matchesRegisteredRoute(String route, Set<String> registeredPatterns) {
  for (final pattern in registeredPatterns) {
    if (pattern == route) return true;
    final regexPattern = pattern.replaceAllMapped(
      RegExp(r':([a-zA-Z0-9_]+)'),
      (match) => r'[^/]+',
    );
    final regex = RegExp('^$regexPattern\$');
    if (regex.hasMatch(route)) return true;
  }
  return false;
}

void main() {
  group('Pro Route Contracts & Navigation Regression Tests', () {
    test('all hardcoded routes in dashboard and tasks must exist in pro_router',
        () {
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
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(proRouterProvider);
      addTearDown(router.dispose);

      final registeredPatterns = _extractRegisteredRoutes(router);

      final dashboardSource = File(
        'lib/features/dashboard/pro_dashboard_screen.dart',
      ).readAsStringSync();
      final tasksSource = File(
        'lib/features/operations/pro_tasks_screen.dart',
      ).readAsStringSync();

      final routeRegex = RegExp(r'''['"](/operasyon/[^'"]+)['"]''');
      final usedRoutes = <String>{};

      for (final match in routeRegex.allMatches(dashboardSource)) {
        usedRoutes.add(match.group(1)!);
      }
      for (final match in routeRegex.allMatches(tasksSource)) {
        usedRoutes.add(match.group(1)!);
      }

      final invalidRoutes = <String>[];
      for (final route in usedRoutes) {
        if (!_matchesRegisteredRoute(route, registeredPatterns)) {
          invalidRoutes.add(route);
        }
      }

      expect(
        invalidRoutes,
        isEmpty,
        reason:
            'Found hard-coded routes not registered in pro_router: $invalidRoutes',
      );
    });

    testWidgets('accounting workspace buttons navigate to real routes',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const accClub = ClubRef(
        id: 'acc-club-1',
        name: 'Kadıköy Finans SK',
        role: 'club_admin',
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('acc-user')),
          ),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              accountantClubIds: {'acc-club-1'},
            ),
          ),
          myClubsProvider.overrideWith((ref) async => const [accClub]),
          selectedAccountantClubIdProvider.overrideWith((ref) => 'acc-club-1'),
          financeOperationsSummaryProvider.overrideWith(
            (ref) async => const FinanceOperationsSummary(
              pendingApprovalCount: 3,
              bankUnmatchedCount: 2,
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({}),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.accounting;
      final router = container.read(proRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final approvalAction = find.widgetWithText(InkWell, 'Harcama Onayı');
      expect(approvalAction, findsOneWidget);
      await tester.ensureVisible(approvalAction);
      await tester.tap(approvalAction);
      await tester.pumpAndSettle();

      expect(find.byType(SharedFinanceOperationsScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      final bankAction = find.widgetWithText(InkWell, 'Banka Mutabakatı');
      expect(bankAction, findsOneWidget);
      await tester.ensureVisible(bankAction);
      await tester.tap(bankAction);
      await tester.pumpAndSettle();

      expect(find.byType(SharedBankReconciliationScreen), findsOneWidget);
    });

    testWidgets(
        'federation workspace bulletin and standings navigate to distinct real routes',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now().toUtc();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('fed-user')),
          ),
          swanAccessProvider.overrideWithValue(
            SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              federationRoles: [
                FederationRole(
                  id: 'r1',
                  federationId: 'fed-1',
                  profileId: 'fed-user',
                  role: FederationRoleKind.president,
                  startsOn: now.subtract(const Duration(days: 5)),
                  endsOn: now.add(const Duration(days: 30)),
                ),
              ],
            ),
          ),
          federationConsoleScopesProvider.overrideWith(
            (ref) async => const [
              FederationConsoleScope(
                federationId: 'fed-1',
                name: 'TFF İstanbul',
                sportCode: 'futbol',
                cityCode: '34',
                role: 'president',
              ),
            ],
          ),
          selectedFederationScopeKeyProvider.overrideWith(
            (ref) => 'fed-1:futbol:34',
          ),
          federationConsoleMatchesProvider.overrideWith(
            (ref, query) async => FederationConsolePage<FederationConsoleMatch>(
              total: 0,
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
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.leagueStandings,
              FeatureFlags.federationBulletin,
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.federation;
      final router = container.read(proRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final standingsAction = find.widgetWithText(InkWell, 'Puan Durumu');
      expect(standingsAction, findsOneWidget);
      await tester.ensureVisible(standingsAction);
      await tester.tap(standingsAction);
      await tester.pumpAndSettle();

      expect(find.byType(SharedLeagueStandingsScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      final bulletinAction = find.widgetWithText(InkWell, 'Bülten');
      expect(bulletinAction, findsOneWidget);
      await tester.ensureVisible(bulletinAction);
      await tester.tap(bulletinAction);
      await tester.pumpAndSettle();

      expect(find.byType(SharedFederationBulletinsScreen), findsOneWidget);
    });

    testWidgets('facility duties navigate to real facility duties route',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now().toUtc();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('fac-user')),
          ),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfDelegation,
            }),
          ),
          turfDutiesProvider(0).overrideWith(
            (ref) async => TurfDutyPage([
              TurfDuty(
                id: 'duty-1',
                fieldId: 'field-1',
                fieldName: 'Saha 1',
                venueName: 'Merkez Tesis',
                issuer: false,
                validUntil: now.add(const Duration(days: 2)),
                inviteUntil: now.add(const Duration(days: 1)),
                status: 'active',
              ),
            ], false),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.facility;
      final router = container.read(proRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/gorevler');
      await tester.pumpAndSettle();

      final inspectAction = find.widgetWithText(FilledButton, 'İncele');
      expect(inspectAction, findsOneWidget);
      await tester.ensureVisible(inspectAction);
      await tester.tap(inspectAction);
      await tester.pumpAndSettle();

      expect(find.byType(SharedManagedTurfDutiesScreen), findsOneWidget);
    });

    testWidgets('platform waitlist navigates to real platform waitlist route',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('plat-user')),
          ),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: true,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({}),
          ),
          launchWaitlistSummaryProvider.overrideWith(
            (ref) async => const LaunchWaitlistSummary(
              totalCount: 4,
              clubCount: 4,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.platform;
      final router = container.read(proRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final waitlistAction = find.widgetWithText(InkWell, 'Bekleme Listesi');
      expect(waitlistAction, findsOneWidget);
      await tester.ensureVisible(waitlistAction);
      await tester.tap(waitlistAction);
      await tester.pumpAndSettle();

      expect(find.byType(SharedLaunchWaitlistScreen), findsOneWidget);
    });

    testWidgets(
        'referee action buttons navigate to referee duties or match report',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now().toUtc();
      final assignedMatch = RefereeMatchSummary(
        officialId: 'off-1',
        matchId: 'match-101',
        homeClubName: 'Kartal SK',
        awayClubName: 'Maltepe SK',
        duty: MatchOfficialDuty.headReferee,
        status: MatchOfficialStatus.assigned,
        matchStatus: 'scheduled',
        assignedAt: now,
        startsAt: now.add(const Duration(days: 1)),
        location: 'Kartal Stadı',
        sportCode: 'futbol',
        cityCode: '34',
      );
      final acceptedMatch = RefereeMatchSummary(
        officialId: 'off-2',
        matchId: 'match-102',
        homeClubName: 'Pendik SK',
        awayClubName: 'Tuzla SK',
        duty: MatchOfficialDuty.headReferee,
        status: MatchOfficialStatus.accepted,
        matchStatus: 'completed',
        assignedAt: now,
        startsAt: now.subtract(const Duration(hours: 3)),
        location: 'Pendik Stadı',
        sportCode: 'futbol',
        cityCode: '34',
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('ref-user')),
          ),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              refereeProfile: RefereeProfile(
                id: 'ref-1',
                profileId: 'ref-user',
                licenseNumber: 'TFF-999',
                badgeTier: RefereeBadgeTier.national,
                sportCode: 'futbol',
                cityCode: '34',
                isActive: true,
              ),
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.refereeCockpit,
            }),
          ),
          refereeDutyMatchesProvider.overrideWith(
            (ref) async => [assignedMatch, acceptedMatch],
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.referee;
      final router = container.read(proRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/gorevler');
      await tester.pumpAndSettle();

      final replyAction = find.widgetWithText(FilledButton, 'Yanıtla');
      expect(replyAction, findsOneWidget);
      await tester.ensureVisible(replyAction);
      await tester.tap(replyAction);
      await tester.pumpAndSettle();

      expect(find.byType(SharedRefereeDutyListScreen), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      final reportTaskAction = find.widgetWithText(FilledButton, 'Rapor Yaz');
      expect(reportTaskAction, findsOneWidget);
      await tester.ensureVisible(reportTaskAction);
      await tester.tap(reportTaskAction);
      await tester.pumpAndSettle();

      expect(find.byType(SharedRefereeMatchReportScreen), findsOneWidget);

      router.go('/panel');
      await tester.pumpAndSettle();

      final reportAction = find.widgetWithText(InkWell, 'Hakem Görevleri');
      expect(reportAction, findsOneWidget);
      await tester.ensureVisible(reportAction);
      await tester.tap(reportAction);
      await tester.pumpAndSettle();
      expect(find.byType(SharedRefereeDutyListScreen), findsOneWidget);
    });

    testWidgets(
        'club applications action is omitted (fail-closed) when no real route exists',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now().toUtc();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('club-user')),
          ),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'club_admin',
              coachLevel: 0,
              athleteKind: null,
            ),
          ),
          proAuthorizedClubsProvider.overrideWithValue(
            const AsyncData([
              ClubRef(id: 'club-1', name: 'Kadıköy SK', role: 'club_admin'),
            ]),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Kadıköy SK',
              role: 'club_admin',
            ),
          ),
          clubTodayAttendanceProvider.overrideWith((ref) async => null),
          clubPendingApplicationsProvider.overrideWith(
            (ref) async => [
              ClubApplicationRow(
                id: 'app-1',
                clubId: 'club-1',
                profileId: 'prof-1',
                desiredRole: 'athlete',
                status: 'pending',
                createdAt: now,
              ),
            ],
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.coachWorkspace,
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.club;
      final router = container.read(proRouterProvider);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Başvurular'), findsNothing);
      expect(find.text('Bekleyen Başvurular'), findsNothing);
    });

    test(
        'federation scope isolation queries scoped results and updates on scope switch',
        () async {
      const basketballScope = FederationConsoleScope(
        federationId: 'fed-1',
        name: 'TBF İstanbul',
        sportCode: 'basketbol',
        cityCode: '34',
        role: 'president',
      );
      const footballScope = FederationConsoleScope(
        federationId: 'fed-1',
        name: 'TFF İstanbul',
        sportCode: 'futbol',
        cityCode: '34',
        role: 'president',
      );

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('fed-iso-user')),
          ),
          swanAccessProvider.overrideWithValue(
            SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              federationRoles: [
                FederationRole(
                  id: 'fed-role-1',
                  federationId: 'fed-1',
                  profileId: 'fed-iso-user',
                  role: FederationRoleKind.president,
                  startsOn: DateTime(2025, 1, 1),
                  endsOn: DateTime(2030, 1, 1),
                ),
              ],
            ),
          ),
          federationConsoleScopesProvider.overrideWith(
            (ref) async => [footballScope, basketballScope],
          ),
          selectedFederationScopeKeyProvider.overrideWith(
            (ref) => 'fed-1:futbol:34',
          ),
          federationScopedPendingResultsProvider.overrideWith(
            (ref, query) async => query.sportCode == 'futbol'
                ? const [
                    FederationPendingMatch(
                      id: 'match-fb-1',
                      name: 'Futbol Ligi',
                      sportCode: 'futbol',
                      version: 1,
                    ),
                  ]
                : const [],
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.federation;

      final sub = container.listen(proPendingTasksCountProvider, (_, __) {});
      addTearDown(sub.close);

      final countFootball =
          await container.read(proPendingTasksCountProvider.future);
      expect(countFootball, 1);

      container.read(selectedFederationScopeKeyProvider.notifier).state =
          'fed-1:basketbol:34';

      final countBasketball =
          await container.read(proPendingTasksCountProvider.future);
      expect(countBasketball, 0);
    });

    testWidgets(
        'task queue models actionable states: loading is not empty, error shows ProErrorState',
        (tester) async {
      final completer = Completer<List<RefereeMatchSummary>>();

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('ref-async-user')),
          ),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              refereeProfile: RefereeProfile(
                id: 'ref-1',
                profileId: 'ref-async-user',
                licenseNumber: 'TFF-888',
                badgeTier: RefereeBadgeTier.national,
                sportCode: 'futbol',
                cityCode: '34',
                isActive: true,
              ),
            ),
          ),
          refereeDutyMatchesProvider.overrideWith((ref) => completer.future),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.referee;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Bekleyen operasyon görevi bulunmuyor'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.completeError(Exception('Network timeout'));
      await tester.pumpAndSettle();

      expect(find.byType(ProErrorState), findsOneWidget);
      expect(find.text('Bekleyen operasyon görevi bulunmuyor'), findsNothing);
    });

    testWidgets('refresh actions invoke scoped data invalidation',
        (tester) async {
      var refereeFetchCount = 0;
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('ref-refresh-user')),
          ),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              refereeProfile: RefereeProfile(
                id: 'ref-1',
                profileId: 'ref-refresh-user',
                licenseNumber: 'TFF-888',
                badgeTier: RefereeBadgeTier.national,
                sportCode: 'futbol',
                cityCode: '34',
                isActive: true,
              ),
            ),
          ),
          refereeDutyMatchesProvider.overrideWith((ref) async {
            refereeFetchCount++;
            return const [];
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.referee;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(refereeFetchCount, 1);

      final refreshBtn = find.byTooltip('Yenile');
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(refereeFetchCount, 2);
    });
  });
}
