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
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/calendar/presentation/screens/schedule_calendar_screen.dart';
import '../features/configuration/presentation/configuration_module_args.dart';
import '../features/configuration/presentation/configuration_screen.dart';
import '../features/dashboard/presentation/screens/coach_dashboard_screen.dart';
import '../features/documents/presentation/routing/document_detail_route_args.dart';
import '../features/documents/presentation/screens/document_detail_screen.dart';
import '../features/documents/presentation/screens/document_vault_screen.dart';
import '../features/facilities/presentation/facility_management_screen.dart';
import '../features/facilities/presentation/facility_route_args.dart';
import '../features/financial_management/presentation/financial_management_screen.dart';
import '../features/financial_management/presentation/financial_route_args.dart';
import '../features/home/presentation/screens/home_command_center_screen.dart';
import '../features/home/presentation/screens/main_hub_dashboard_screen.dart';
import '../features/home/presentation/screens/public_landing_screen.dart';
import '../features/medical_center/presentation/medical_center_screen.dart';
import '../features/medical_center/presentation/medical_route_args.dart';
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
import '../features/teams/presentation/screens/team_roster_directory_screen.dart';
import 'config/app_environment.dart';

class SwanSportApp extends ConsumerWidget {
  const SwanSportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);

    return MaterialApp(
      title: environment.appName,
      debugShowCheckedModeBanner: false,
      theme: SwanTheme.light(),
      darkTheme: SwanTheme.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthScreen(),
        '/home-command': (context) => const HomeCommandCenterScreen(),
        '/landing': (context) => const PublicLandingScreen(),
        '/hub': (context) => const MainHubDashboardScreen(),
        '/dashboard': (context) => const CoachDashboardScreen(),
        '/athletes': (context) => const AthleteWorkspaceScreen(),
        '/attendance': (context) => const LiveAttendanceScreen(),
        '/calendar': (context) => const ScheduleCalendarScreen(),
        '/announcements': (context) => const AnnouncementsScreen(),
        '/teams': (context) => const TeamRosterDirectoryScreen(),
        '/documents': (context) => const DocumentVaultScreen(),
        '/settings': (context) => const ClubSettingsScreen(),
        '/configuration': (context) => const ConfigurationScreen(),
        '/facilities': (context) => const FacilityManagementScreen(),
        '/medical-center': (context) => const MedicalCenterScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/financial-management': (context) => const FinancialManagementScreen(),
        '/performance-analytics': (context) =>
            const PerformanceAnalyticsScreen(),
      },
      onGenerateRoute: (settings) {
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
        if (settings.name == '/facility-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => FacilityDetailScreen(
              args: args is FacilityDetailArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/medical-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => MedicalDetailScreen(
              args: args is MedicalDetailArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/financial-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => FinancialDetailScreen(
              args: args is FinancialDetailArgs ? args : null,
            ),
          );
        }
        if (settings.name == '/performance-detail') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PerformanceDetailScreen(
              args: args is PerformanceDetailArgs ? args : null,
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
        if (settings.name == '/performance-test-session') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => TestSessionScreen(
              args: args is TestSessionArgs ? args : null,
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
