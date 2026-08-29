import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../features/announcements/presentation/routing/communication_detail_route_args.dart';
import '../features/announcements/presentation/screens/announcements_screen.dart';
import '../features/announcements/presentation/screens/communication_detail_screen.dart';
import '../features/athlete_workspace/presentation/routing/athlete_detail_route_args.dart';
import '../features/athlete_workspace/presentation/screens/athlete_detail_screen.dart';
import '../features/athlete_workspace/presentation/screens/athlete_workspace_screen.dart';
import '../features/attendance/presentation/screens/live_attendance_screen.dart';
import '../features/auth/presentation/screens/auth_gate.dart';
import '../features/calendar/presentation/screens/schedule_calendar_screen.dart';
import '../features/configuration/presentation/configuration_module_args.dart';
import '../features/configuration/presentation/configuration_screen.dart';
import '../features/dashboard/presentation/screens/coach_dashboard_screen.dart';
import '../features/documents/presentation/routing/document_detail_route_args.dart';
import '../features/documents/presentation/screens/document_detail_screen.dart';
import '../features/documents/presentation/screens/document_vault_screen.dart';
import '../features/facilities/presentation/facility_management_screen.dart';
import '../features/facilities/presentation/facility_route_args.dart';
import '../features/home/presentation/screens/home_command_center_screen.dart';
import '../features/home/presentation/screens/public_landing_screen.dart';
import '../features/medical_center/presentation/medical_center_screen.dart';
import '../features/medical_center/presentation/medical_route_args.dart';
import '../features/performance_analytics/presentation/athlete_performance_screen.dart';
import '../features/performance_analytics/presentation/performance_analytics_screen.dart';
import '../features/performance_analytics/presentation/performance_route_args.dart';
import '../features/performance_analytics/presentation/performance_workflow_editors.dart';
import '../features/performance_analytics/presentation/performance_workflow_screens.dart';
import '../features/reports/presentation/routing/report_detail_args.dart';
import '../features/reports/presentation/screens/report_detail_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/settings/presentation/routing/admin_user_detail_args.dart';
import '../features/settings/presentation/screens/admin_user_detail_screen.dart';
import '../features/settings/presentation/screens/club_settings_screen.dart';
import '../features/clubs/presentation/club_applications_screen.dart';
import '../features/demo/demo_role_screen.dart';
import '../features/social/presentation/connections_screen.dart';
import '../features/communities/presentation/communities_screen.dart';
import '../features/network/presentation/discover_screen.dart';
import '../features/network/presentation/listings_screen.dart';
import '../features/network/presentation/organizations_screen.dart';
import '../features/financial_management/presentation/campaigns_screen.dart';
import '../features/financial_management/presentation/finance_screen.dart';
import '../features/financial_management/presentation/my_fees_screen.dart';
import '../features/communities/presentation/community_chat_screen.dart';
import '../features/communities/presentation/federation_admin_screen.dart';
import '../features/communities/presentation/federation_channel_screen.dart';
import '../features/courts/presentation/courts_screen.dart';
import '../features/courts/presentation/find_partner_screen.dart';
import '../features/courts/presentation/open_slots_screen.dart';
import '../features/social/presentation/feed_screen.dart';
import '../features/social/presentation/profile_screen.dart';
import '../features/social/presentation/messages_screen.dart';
import '../features/social/presentation/notifications_screen.dart';
import '../features/social/presentation/privacy_screen.dart';
import '../features/social/presentation/rss_admin_screen.dart';
import '../features/social/presentation/search_screen.dart';
import '../features/verification/presentation/admin_review_screen.dart';
import '../features/financial_management/presentation/quick_expense_screen.dart';
import '../features/verification/presentation/club_pending_screen.dart';
import '../features/verification/presentation/credential_screen.dart';
import '../features/verification/presentation/guardian_link_screen.dart';
import '../features/attendance/presentation/screens/attendance_history_screen.dart';
import '../features/teams/presentation/screens/team_roster_directory_screen.dart';
import '../features/teams/presentation/screens/team_roster_screen.dart';
import 'config/app_environment.dart';
import 'app_navigator.dart';
import 'widgets/page_transitions.dart';

class SwanSportApp extends ConsumerWidget {
  const SwanSportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);

    return MaterialApp(
      title: environment.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: swanNavigatorKey,
      scaffoldMessengerKey: swanMessengerKey,
      theme: SwanTheme.light().copyWith(
        pageTransitionsTheme: kSwanPageTransitions,
      ),
      darkTheme: SwanTheme.dark().copyWith(
        pageTransitionsTheme: kSwanPageTransitions,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/home-command': (context) => const HomeCommandCenterScreen(),
        '/landing': (context) => const PublicLandingScreen(),
        '/dashboard': (context) => const CoachDashboardScreen(),
        '/athletes': (context) => const AthleteWorkspaceScreen(),
        '/attendance': (context) => const LiveAttendanceScreen(),
        '/calendar': (context) => const ScheduleCalendarScreen(),
        '/announcements': (context) => const AnnouncementsScreen(),
        '/teams': (context) => const TeamRosterDirectoryScreen(),
        '/documents': (context) => const DocumentVaultScreen(),
        '/settings': (context) => const ClubSettingsScreen(),
        '/gider-ekle': (context) => const QuickExpenseScreen(),
        '/dogrulama': (context) => const CredentialScreen(),
        '/veli-bagla': (context) => const GuardianLinkScreen(),
        '/onay-paneli': (context) => const AdminReviewScreen(),
        '/demo-rol': (context) => const DemoRoleScreen(),
        '/akis': (context) => const FeedScreen(),
        '/ara': (context) => const SearchScreen(),
        '/bildirimler': (context) => const NotificationsScreen(),
        '/mesajlar': (context) => const MessagesScreen(),
        '/topluluklar': (context) => const CommunitiesScreen(),
        '/kesfet': (context) => const DiscoverScreen(),
        '/ilanlar': (context) => const ListingsScreen(),
        '/kortlar': (context) => const CourtsScreen(),
        '/oyuncu-aranan': (context) => const OpenSlotsScreen(),
        '/partner-ara': (context) => const FindPartnerScreen(),
        '/organizasyonlar': (context) => const OrganizationsScreen(),
        '/finans': (context) => const FinanceScreen(),
        '/aidatlarim': (context) => const MyFeesScreen(),
        '/bagis': (context) => const CampaignsScreen(),
        '/federasyon-yetkili': (context) => const FederationAdminScreen(),
        '/haber-kaynaklari': (context) => const RssAdminScreen(),
        '/gizlilik': (context) => const PrivacyScreen(),
        '/devam-durumu': (context) => const AttendanceHistoryScreen(),
        '/basvurular': (context) => const ClubApplicationsScreen(),
        '/configuration': (context) => const ConfigurationScreen(),
        '/facilities': (context) => const FacilityManagementScreen(),
        '/medical-center': (context) => const MedicalCenterScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/performance-analytics': (context) =>
            const PerformanceAnalyticsScreen(),
      },
      onGenerateRoute: (settings) {
        // Sosyal profiller — argüman: profil/kulüp id'si (yoksa kendi profilin)
        if (settings.name == '/profil' || settings.name == '/kulup-profil') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ProfileScreen(
              id: args is String ? args : null,
              isClub: settings.name == '/kulup-profil',
            ),
          );
        }
        if (settings.name == '/sporcu-performans') {
          final args = settings.arguments;
          final m = args is Map ? args : const {};
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => AthletePerformanceScreen(
              athleteId: '${m['id'] ?? ''}',
              athleteName: '${m['name'] ?? 'Sporcu'}',
            ),
          );
        }
        if (settings.name == '/baglantilar') {
          final args = settings.arguments;
          final m = args is Map ? args : const {};
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ConnectionsScreen(
              profileId: '${m['id'] ?? ''}',
              initialTab: (m['tab'] as int?) ?? 0,
              title: m['name'] as String?,
            ),
          );
        }
        if (settings.name == '/takim-kadro') {
          final args = settings.arguments;
          final m = args is Map ? args : const {};
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => TeamRosterScreen(
              teamId: '${m['id'] ?? ''}',
              teamName: '${m['name'] ?? 'Takım'}',
            ),
          );
        }
        if (settings.name == '/federasyon') {
          final args = settings.arguments;
          final m = args is Map ? args : const {};
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => FederationChannelScreen(
              communityId: '${m['id'] ?? ''}',
              title: '${m['name'] ?? 'Federasyon'}',
            ),
          );
        }
        if (settings.name == '/topluluk') {
          final args = settings.arguments;
          final m = args is Map ? args : const {};
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => CommunityChatScreen(
              communityId: '${m['id'] ?? ''}',
              title: '${m['name'] ?? 'Topluluk'}',
            ),
          );
        }
        if (settings.name == '/sohbet') {
          final args = settings.arguments;
          final m = args is Map ? args : const {};
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ChatScreen(
              otherId: '${m['id'] ?? ''}',
              otherName: '${m['name'] ?? 'Sohbet'}',
            ),
          );
        }
        if (settings.name == '/athlete-detail') {
          final args = settings.arguments;

          if (args is AthleteDetailRouteArgs) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => AthleteDetailScreen(args: args),
            );
          }

          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => const AthleteDetailScreen.invalidRoute(),
          );
        }
        if (settings.name == '/communication-detail') {
          final args = settings.arguments;

          if (args is CommunicationDetailRouteArgs) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => CommunicationDetailScreen(args: args),
            );
          }

          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) =>
                const CommunicationDetailScreen.invalidRoute(),
          );
        }
        if (settings.name == '/document-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => args is DocumentDetailRouteArgs
                ? DocumentDetailScreen(args: args)
                : const DocumentDetailScreen.invalidRoute(),
          );
        }
        if (settings.name == '/admin-user-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => AdminUserDetailScreen(
              args: args is AdminUserDetailArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/configuration-module') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ConfigurationModuleScreen(
              args: args is ConfigurationModuleArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-test-session') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => TestSessionScreen(
              args: args is TestSessionArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-team-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => TeamPerformanceScreen(
              args: args is TeamPerformanceArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-development-plan') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => DevelopmentPlanScreen(
              args: args is DevelopmentPlanArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-review-session') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ReviewSessionScreen(
              args: args is ReviewSessionArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-match-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => MatchPerformanceScreen(
              args: args is MatchPerformanceArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-training-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => TrainingPerformanceScreen(
              args: args is TrainingPerformanceArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-position-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PositionAnalysisScreen(
              args: args is PositionAnalysisArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-test-session-editor') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => TestSessionEditorScreen(
              args: args is TestSessionEditorArgs
                  ? args
                  : const TestSessionEditorArgs(),
            ),
          );
        }
        if (settings.name == '/performance-development-plan-editor') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => DevelopmentPlanEditorScreen(
              args: args is DevelopmentPlanEditorArgs
                  ? args
                  : const DevelopmentPlanEditorArgs(),
            ),
          );
        }
        if (settings.name == '/performance-self-assessment-editor') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => SelfAssessmentEditorScreen(
              args: args is SelfAssessmentEditorArgs
                  ? args
                  : const SelfAssessmentEditorArgs(),
            ),
          );
        }
        if (settings.name == '/performance-review-session-editor') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ReviewSessionEditorScreen(
              args: args is ReviewSessionEditorArgs
                  ? args
                  : const ReviewSessionEditorArgs(),
            ),
          );
        }
        if (settings.name == '/report-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ReportDetailScreen(
              args: args is ReportDetailArgs ? args : null,
            ),
          );
        }

        return null;
      },
    );
  }
}
