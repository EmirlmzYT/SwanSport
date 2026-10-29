import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/account/pro_account_screen.dart';
import '../features/calendar/pro_calendar_screen.dart';
import '../features/dashboard/pro_dashboard_screen.dart';
import '../features/operations/pro_operations_gate.dart';
import '../features/operations/pro_tasks_screen.dart';
import '../shell/pro_shell.dart';
import 'push/pro_notification_route_handler.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

abstract final class ProRoutes {
  static const panel = '/panel';
  static const tasks = '/gorevler';
  static const calendar = '/takvim';
  static const inbox = '/gelen-kutusu';
  static const account = '/hesap';

  // Operations - Club / Coach
  static const teams = '/operasyon/takimlar';
  static const attendance = '/operasyon/yoklama';
  static const attendanceHistory = '/operasyon/devam';
  static const teamRosterPattern = '/operasyon/takim/:id';
  static String teamRoster(String id) => '/operasyon/takim/$id';
  static const trainings = '/operasyon/antrenmanlar';
  static const trainingProtocols = '/operasyon/antrenman-sablonlari';
  static const trainingBuilder = '/operasyon/antrenman-olustur';
  static const trainingSession = '/operasyon/antrenman-oturumu';
  static const trainingResult = '/operasyon/antrenman-sonuc';

  // Federation
  static const federationMatches = '/operasyon/federasyon-maclar';
  static const refereeAssignments = '/operasyon/hakem-atamalari';
  static const leagueStandings = '/operasyon/puan-durumu';
  static const disciplinaryBoard = '/operasyon/disiplin-kurulu';
  static const federationBulletin = '/operasyon/federasyon-bulten';

  // Referee
  static const refereeDuties = '/operasyon/hakem-gorevleri';
  static const refereeLineupPattern = '/operasyon/hakem-esame/:id';
  static String refereeLineup(String matchId) =>
      '/operasyon/hakem-esame/$matchId';
  static const refereeLivePattern = '/operasyon/hakem-canli/:id';
  static String refereeLive(String matchId) =>
      '/operasyon/hakem-canli/$matchId';
  static const refereeReportPattern = '/operasyon/hakem-rapor/:id';
  static String refereeReport(String matchId) =>
      '/operasyon/hakem-rapor/$matchId';

  // Accounting
  static const accounting = '/operasyon/muhasebe';
  static const accountingLedger = '/operasyon/muhasebe-defter';
  static const accountingCommitments = '/operasyon/mali-taahhutler';
  static const bankReconciliation = '/operasyon/banka-mutabakati';
  static const clubBudget = '/operasyon/kulup-butcesi';
  static const periodClosing = '/operasyon/donem-kapanisi';

  // Facility
  static const facility = '/operasyon/tesis';
  static const facilityCalendar = '/operasyon/tesis-takvim';
  static const facilityReservations = '/operasyon/tesis-rezervasyonlar';
  static const facilityDuties = '/operasyon/tesis-gorevleri';

  // Club specialist
  static const clubInventory = '/operasyon/kulup-envanter';
  static const clubHealth = '/operasyon/kulup-saglik';
  static const clubPlanning = '/operasyon/kulup-sportif-planlama';
  static const developmentReport = '/operasyon/gelisim-raporu';

  // Platform
  static const platform = '/operasyon/platform';
  static const platformStatus = '/operasyon/platform-durum';
  static const platformAudit = '/operasyon/platform-denetim';
  static const platformPlans = '/operasyon/platform-planlar';
  static const platformWaitlist = '/operasyon/platform-bekleme-listesi';

  /// Immutable contract of all patterns registered in pro_router
  static const registeredPatterns = <String>{};
}

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
                builder: (context, state) => const ProCalendarScreen(),
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
