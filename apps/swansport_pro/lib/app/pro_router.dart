import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/account/pro_account_screen.dart';
import '../features/dashboard/pro_dashboard_screen.dart';
import '../features/operations/pro_operations_gate.dart';
import '../features/operations/pro_tasks_screen.dart';
import '../features/placeholders/pro_placeholder_screen.dart';
import '../shell/pro_shell.dart';
import 'push/pro_notification_route_handler.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final _panelNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'panelNav');
final _tasksNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'tasksNav');
final _calendarNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'calendarNav');
final _inboxNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'inboxNav');
final _accountNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'accountNav');

final proRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/panel',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ProShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _panelNavigatorKey,
            routes: [
              GoRoute(
                path: '/panel',
                builder: (context, state) => const ProDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _tasksNavigatorKey,
            routes: [
              GoRoute(
                path: '/gorevler',
                builder: (context, state) => const ProTasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _calendarNavigatorKey,
            routes: [
              GoRoute(
                path: '/takvim',
                builder: (context, state) =>
                    const ProPlaceholderScreen(title: 'Takvim'),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _inboxNavigatorKey,
            routes: [
              GoRoute(
                path: '/gelen-kutusu',
                builder: (context, state) => SharedProInboxScreen(
                  onNotificationTap: (notification) =>
                      handleProNotificationTap(context, notification),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _accountNavigatorKey,
            routes: [
              GoRoute(
                path: '/hesap',
                builder: (context, state) => const ProAccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/takimlar',
        builder: (context, state) => const ProOperationsGate(
          child: SharedTeamDirectoryScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/yoklama',
        builder: (context, state) => const ProOperationsGate(
          child: SharedLiveAttendanceScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/devam',
        builder: (context, state) => const ProOperationsGate(
          child: SharedAttendanceHistoryScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/takim/:id',
        builder: (context, state) {
          final extra = state.extra;
          final id = state.pathParameters['id'] ?? '';
          final target = extra is TeamRouteTarget
              ? extra
              : TeamRouteTarget(teamId: id, teamName: 'Takım');
          return ProOperationsGate(
            child: SharedTeamRosterScreen(target: target),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/antrenmanlar',
        builder: (context, state) => const ProOperationsGate(
          child: SharedTrainingListScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/antrenman-sablonlari',
        builder: (context, state) => const ProOperationsGate(
          child: SharedProtocolListScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/antrenman-olustur',
        builder: (context, state) => const ProOperationsGate(
          child: SharedWorkoutBuilderScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/antrenman-oturumu',
        builder: (context, state) {
          final extra = state.extra;
          return ProOperationsGate(
            child: SharedTrainingSessionScreen(
              sessionId: extra is String ? extra : null,
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/antrenman-sonuc',
        builder: (context, state) {
          final extra = state.extra;
          return ProOperationsGate(
            child: SharedSessionResultScreen(
              sessionId: extra is String ? extra : '',
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/federasyon-maclar',
        builder: (context, state) => const ProFederationOperationsGate(
          child: SharedFederationMatchesScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/hakem-atamalari',
        builder: (context, state) => const ProFederationOperationsGate(
          child: SharedRefereeAssignmentsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/puan-durumu',
        builder: (context, state) => const ProFederationOperationsGate(
          child: SharedLeagueStandingsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/disiplin-kurulu',
        builder: (context, state) => const ProFederationOperationsGate(
          child: SharedDisciplinaryBoardScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/federasyon-bulten',
        builder: (context, state) => const ProFederationOperationsGate(
          child: SharedFederationBulletinsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/hakem-gorevleri',
        builder: (context, state) => const ProRefereeOperationsGate(
          child: SharedRefereeDutyListScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/hakem-esame/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProRefereeOperationsGate(
            child: SharedRefereeLineupApprovalScreen(matchId: id),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/hakem-canli/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProRefereeOperationsGate(
            child: SharedRefereeLiveCockpitScreen(matchId: id),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/hakem-rapor/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProRefereeOperationsGate(
            child: SharedRefereeMatchReportScreen(matchId: id),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/muhasebe',
        builder: (context, state) => const ProAccountingOperationsGate(
          child: SharedFinanceOperationsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/muhasebe-defter',
        builder: (context, state) => const ProAccountingOperationsGate(
          child: SharedFinanceLedgerScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/mali-taahhutler',
        builder: (context, state) => const ProAccountingOperationsGate(
          child: SharedFinanceCommitmentsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/banka-mutabakati',
        builder: (context, state) => const ProAccountingOperationsGate(
          child: SharedBankReconciliationScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/kulup-butcesi',
        builder: (context, state) => const ProAccountingOperationsGate(
          child: SharedClubBudgetScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/donem-kapanisi',
        builder: (context, state) => const ProAccountingOperationsGate(
          child: SharedPeriodClosingScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/tesis',
        builder: (context, state) => const ProFacilityOperationsGate(
          child: SharedFacilityOperationsPanel(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/tesis-takvim',
        builder: (context, state) => const ProFacilityOperationsGate(
          child: SharedFacilityScheduleScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/tesis-rezervasyonlar',
        builder: (context, state) => const ProFacilityOperationsGate(
          child: SharedFacilityReservationsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/tesis-gorevleri',
        builder: (context, state) => const ProFacilityOperationsGate(
          child: SharedManagedTurfDutiesScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/kulup-envanter',
        builder: (context, state) => const ProClubSpecialistOperationsGate(
          child: SharedClubInventoryScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/kulup-saglik',
        builder: (context, state) => const ProClubSpecialistOperationsGate(
          child: SharedClubHealthOperationsScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/kulup-sportif-planlama',
        builder: (context, state) => const ProClubSpecialistOperationsGate(
          child: SharedClubSportingPlanningScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/gelisim-raporu',
        builder: (context, state) => const ProClubSpecialistOperationsGate(
          child: SharedDevelopmentReportScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/platform',
        builder: (context, state) => const ProPlatformOperationsGate(
          child: SharedPlatformOperationsPanel(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/platform-durum',
        builder: (context, state) => const ProPlatformOperationsGate(
          child: SharedPlatformStatusScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/platform-denetim',
        builder: (context, state) => const ProPlatformOperationsGate(
          child: SharedPlatformAuditScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/platform-planlar',
        builder: (context, state) => const ProPlatformOperationsGate(
          child: SharedPlatformPlansScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/operasyon/platform-bekleme-listesi',
        builder: (context, state) => const ProPlatformOperationsGate(
          child: SharedLaunchWaitlistScreen(),
        ),
      ),
    ],
  );
});
