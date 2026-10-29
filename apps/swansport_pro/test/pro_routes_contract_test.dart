import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_router.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro/features/operations/pro_club_context_selector.dart';
import 'package:swansport_pro/features/operations/pro_tasks_controller.dart';
import 'package:swansport_pro/features/operations/pro_tasks_screen.dart';
import 'package:swansport_pro/widgets/pro_context_bar.dart';
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
    test('route contract: unregistered fake pattern is caught by contract test',
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

      final routerPatterns = _extractRegisteredRoutes(router);
      const fakePattern = '/operasyon/sahte-uydurma-rota';

      expect(routerPatterns.contains(fakePattern), isFalse);
      expect(
        _matchesRegisteredRoute(fakePattern, routerPatterns),
        isFalse,
        reason: 'Unregistered fake route must not match router configuration',
      );
    });

    test(
        'route contract: parameterized URL builders match registered route patterns',
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

      final routerPatterns = _extractRegisteredRoutes(router);

      expect(
        _matchesRegisteredRoute(
            ProRoutes.teamRoster('team-123'), routerPatterns),
        isTrue,
      );
      expect(
        _matchesRegisteredRoute(
            ProRoutes.refereeLineup('match-456'), routerPatterns),
        isTrue,
      );
      expect(
        _matchesRegisteredRoute(
            ProRoutes.refereeLive('match-789'), routerPatterns),
        isTrue,
      );
      expect(
        _matchesRegisteredRoute(
            ProRoutes.refereeReport('match-999'), routerPatterns),
        isTrue,
      );
    });

    test(
        'route contract: registeredPatterns strictly matches router configuration bidirectionally',
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

      final routerPatterns = _extractRegisteredRoutes(router);
      final contractPatterns = ProRoutes.registeredPatterns;

      final inContractNotRouter = contractPatterns.difference(routerPatterns);
      final inRouterNotContract = routerPatterns.difference(contractPatterns);

      expect(
        inContractNotRouter,
        isEmpty,
        reason:
            'Patterns in ProRoutes.registeredPatterns but missing in router: $inContractNotRouter',
      );
      expect(
        inRouterNotContract,
        isEmpty,
        reason:
            'Patterns in router but missing in ProRoutes.registeredPatterns: $inRouterNotContract',
      );
    });

    testWidgets(
        'club workspace loading hides empty state in both tasks and dashboard',
        (tester) async {
      final completer = Completer<ClubTodayAttendance?>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('club-loading-user')),
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
          clubTodayAttendanceProvider.overrideWith((ref) => completer.future),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.club;

      // 1. ProTasksScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Bekleyen operasyon görevi bulunmuyor'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 2. ProDashboardScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProDashboardScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Bugün için bekleyen acil işlem yok'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets(
        'club workspace error shows ProErrorState and hides empty state in both tasks and dashboard',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('club-error-user')),
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
          clubTodayAttendanceProvider.overrideWith(
            (ref) => Future.error(Exception('Failed to fetch attendance')),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.club;

      // 1. ProTasksScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProErrorState), findsOneWidget);
      expect(find.text('Bekleyen operasyon görevi bulunmuyor'), findsNothing);

      // 2. ProDashboardScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProErrorState), findsWidgets);
      expect(find.text('Bugün için bekleyen acil işlem yok'), findsNothing);
      expect(find.text('Tüm operasyonel süreçler güncel ve yolunda.'),
          findsNothing);
    });

    testWidgets(
        'club workspace success null or empty data shows real empty state in both tasks and dashboard',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('club-empty-user')),
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
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.club;

      // 1. ProTasksScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen operasyon görevi bulunmuyor'), findsOneWidget);

      // 2. ProDashboardScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bugün için bekleyen acil işlem yok'), findsOneWidget);
    });

    testWidgets(
        'club workspace with unrecorded attendance shows attendance task in both tasks and dashboard',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('club-att-user')),
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
          clubTodayAttendanceProvider.overrideWith(
            (ref) async =>
                const ClubTodayAttendance(trainingCount: 2, markedCount: 0),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.club;

      // 1. ProTasksScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Günün Antrenman Yoklaması'), findsOneWidget);

      // 2. ProDashboardScreen
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Günün Yoklaması'), findsOneWidget);
    });

    testWidgets(
        'federation refresh invalidates scoped results and increments fetch count',
        (tester) async {
      final now = DateTime.now().toUtc();
      var pendingFetchCount = 0;
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('fed-refresh-user')),
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
                  profileId: 'fed-refresh-user',
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
          federationScopedPendingResultsProvider.overrideWith(
            (ref, query) async {
              pendingFetchCount++;
              return const [
                FederationPendingMatch(
                  id: 'match-fed-1',
                  name: 'Süper Amatör',
                  sportCode: 'futbol',
                  version: 1,
                ),
              ];
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.federation;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(pendingFetchCount, 1);

      final refreshBtn = find.byTooltip('Yenile');
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(pendingFetchCount, 2);
    });

    testWidgets(
        'federation scope transition switches query to new sport without state leakage',
        (tester) async {
      final now = DateTime.now().toUtc();
      var footballQueryCount = 0;
      var basketballQueryCount = 0;
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('fed-leak-user')),
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
                  profileId: 'fed-leak-user',
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
                name: 'TFF Futbol',
                sportCode: 'futbol',
                cityCode: '34',
                role: 'president',
              ),
              FederationConsoleScope(
                federationId: 'fed-1',
                name: 'TBF Basketbol',
                sportCode: 'basketbol',
                cityCode: '34',
                role: 'president',
              ),
            ],
          ),
          selectedFederationScopeKeyProvider.overrideWith(
            (ref) => 'fed-1:futbol:34',
          ),
          federationScopedPendingResultsProvider.overrideWith(
            (ref, query) async {
              if (query.sportCode == 'futbol') {
                footballQueryCount++;
                return const [
                  FederationPendingMatch(
                    id: 'match-fb',
                    name: 'Futbol Maçı',
                    sportCode: 'futbol',
                    version: 1,
                  ),
                ];
              } else if (query.sportCode == 'basketbol') {
                basketballQueryCount++;
                return const [
                  FederationPendingMatch(
                    id: 'match-bb',
                    name: 'Basketbol Maçı',
                    sportCode: 'basketbol',
                    version: 1,
                  ),
                ];
              }
              return const [];
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.federation;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(footballQueryCount, 1);
      expect(basketballQueryCount, 0);
      expect(find.textContaining('1 müsabaka sonuç onayı'), findsOneWidget);

      // Transition to basketball
      container.read(selectedFederationScopeKeyProvider.notifier).state =
          'fed-1:basketbol:34';
      await tester.pumpAndSettle();

      expect(basketballQueryCount, 1);
      expect(find.textContaining('1 müsabaka sonuç onayı'), findsOneWidget);
    });

    testWidgets(
        'federation scopes error does not show fake zero or empty success',
        (tester) async {
      final now = DateTime.now().toUtc();
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('fed-error-user')),
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
                  profileId: 'fed-error-user',
                  role: FederationRoleKind.president,
                  startsOn: now.subtract(const Duration(days: 5)),
                  endsOn: now.add(const Duration(days: 30)),
                ),
              ],
            ),
          ),
          federationConsoleScopesProvider.overrideWith(
            (ref) => Future.error(Exception('Scope fetch failed')),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.federation;

      // 1. ProTasksScreen shows ProErrorState, not empty
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProTasksScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProErrorState), findsOneWidget);
      expect(find.text('Bekleyen operasyon görevi bulunmuyor'), findsNothing);

      // 2. ProDashboardScreen shows ProErrorState, not empty
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProErrorState), findsWidgets);
      expect(find.text('Bugün için bekleyen acil işlem yok'), findsNothing);
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

    testWidgets(
        'mobile context bar provides accessible club switcher with guarded transition',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const clubA =
          ClubRef(id: 'club-a', name: 'Kadıköy SK', role: 'club_admin');
      const clubB =
          ClubRef(id: 'club-b', name: 'Beşiktaş SK', role: 'club_admin');

      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession('user-mobile-scope')),
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
            const AsyncData([clubA, clubB]),
          ),
          selectedClubIdProvider.overrideWith((ref) => 'club-a'),
        ],
      );
      addTearDown(container.dispose);
      container.read(selectedProWorkspaceProvider.notifier).state =
          ProWorkspace.club;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ProContextBar(compact: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchBtnFinder =
          find.byKey(const Key('pro-mobile-club-selector-button'));
      expect(switchBtnFinder, findsOneWidget);

      final size = tester.getSize(switchBtnFinder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(switchBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Kulüp Değiştir'), findsOneWidget);
      expect(find.text('Beşiktaş SK'), findsOneWidget);

      await tester.tap(find.text('Beşiktaş SK'));
      await tester.pumpAndSettle();

      expect(container.read(selectedClubIdProvider), 'club-b');
    });
  });
}
