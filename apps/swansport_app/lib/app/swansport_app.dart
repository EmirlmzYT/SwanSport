import 'widgets/action_gate.dart';
import '../features/network/presentation/guest_explore_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../features/announcements/presentation/routing/communication_detail_route_args.dart';
import '../features/announcements/presentation/screens/announcements_screen.dart';
import '../features/announcements/presentation/screens/communication_detail_screen.dart';
import '../features/athlete_workspace/presentation/routing/athlete_detail_route_args.dart';
import '../features/athlete_workspace/presentation/screens/athlete_detail_screen.dart';
import '../features/athlete_workspace/presentation/screens/athlete_workspace_screen.dart';
import '../features/athlete_workspace/presentation/screens/nutrition_tracker_screen.dart';
import '../features/attendance/presentation/screens/attendance_history_screen.dart';
import '../features/attendance/presentation/screens/live_attendance_screen.dart';
import '../features/auth/presentation/screens/auth_gate.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/calendar/presentation/screens/event_roster_detail_screen.dart';
import '../features/calendar/presentation/screens/race_event_detail_screen.dart';
import '../features/calendar/presentation/screens/schedule_calendar_screen.dart';
import '../features/clubs/presentation/club_applications_screen.dart';
import '../features/clubs/presentation/club_profile_detail_screen.dart';
import '../features/communities/presentation/community_chat_screen.dart';
import '../features/communities/presentation/federation_admin_screen.dart';
import '../features/communities/presentation/federation_channel_screen.dart';
import '../features/configuration/presentation/configuration_module_args.dart';
import '../features/configuration/presentation/configuration_screen.dart';
import '../features/configuration/presentation/season_setup_screen.dart';
import '../features/courts/presentation/find_partner_screen.dart';
import '../features/courts/presentation/venues_screen.dart';
import '../features/dashboard/presentation/screens/coach_dashboard_screen.dart';
import '../features/demo/demo_role_screen.dart';
import '../features/documents/presentation/routing/document_detail_route_args.dart';
import '../features/documents/presentation/screens/document_detail_screen.dart';
import '../features/documents/presentation/screens/document_vault_screen.dart';
import '../features/equipment/presentation/equipment_tuning_screen.dart';
import '../features/facilities/presentation/facility_management_screen.dart';
import '../features/facilities/presentation/facility_reservation_screen.dart';
import '../features/financial_management/presentation/accountant_privacy_ledger_screen.dart';
import '../features/financial_management/presentation/campaigns_screen.dart';
import '../features/financial_management/presentation/closed_period_reversal_screen.dart';
import '../features/financial_management/presentation/finance_screen.dart';
import '../features/financial_management/presentation/finance_tasks_screen.dart';
import '../features/financial_management/presentation/my_fees_screen.dart';
import '../features/financial_management/presentation/quick_expense_screen.dart';
import '../features/home/presentation/screens/home_command_center_screen.dart';
import '../features/home/presentation/screens/public_landing_screen.dart';
import '../features/marketplace/presentation/cart_checkout_screen.dart';
import '../features/marketplace/presentation/create_listing_screen.dart';
import '../features/marketplace/presentation/listing_detail_screen.dart';
import '../features/marketplace/presentation/marketplace_screen.dart';
import '../features/marketplace/presentation/store_application_screen.dart';
import '../features/medical_center/presentation/medical_center_screen.dart';
import '../features/network/presentation/coach_discovery_screen.dart';
import '../features/network/presentation/discover_screen.dart';
import '../features/network/presentation/explore_screen.dart';
import '../features/network/presentation/listings_screen.dart';
import '../features/network/presentation/organizations_screen.dart';
import '../features/performance_analytics/presentation/athlete_performance_screen.dart';
import '../features/performance_analytics/presentation/leaderboard_screen.dart';
import '../features/performance_analytics/presentation/performance_analytics_screen.dart';
import '../features/performance_analytics/presentation/performance_route_args.dart';
import '../features/performance_analytics/presentation/performance_workflow_editors.dart';
import '../features/performance_analytics/presentation/performance_workflow_screens.dart';
import '../features/performance_analytics/presentation/readiness_rpe_screen.dart';
import '../features/reports/presentation/routing/report_detail_args.dart';
import '../features/reports/presentation/screens/development_report_screen.dart';
import '../features/reports/presentation/screens/report_detail_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/saha_operations/presentation/saha_operations_screen.dart';
import '../features/settings/presentation/routing/admin_user_detail_args.dart';
import '../features/settings/presentation/screens/admin_user_detail_screen.dart';
import '../features/settings/presentation/screens/club_settings_screen.dart';
import '../features/social/presentation/connections_screen.dart';
import '../features/social/presentation/feed_screen.dart';
import '../features/social/presentation/messages_screen.dart';
import '../features/social/presentation/notifications_screen.dart';
import '../features/social/presentation/privacy_screen.dart';
import '../features/social/presentation/profile_screen.dart';
import '../features/social/presentation/rss_admin_screen.dart';
import '../features/social/presentation/saved_posts_screen.dart';
import '../features/social/presentation/search_screen.dart';
import '../features/support/presentation/help_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/teams/presentation/screens/team_roster_directory_screen.dart';
import '../features/teams/presentation/screens/team_roster_screen.dart';
import '../features/training/presentation/match_simulation_screen.dart';
import '../features/training/presentation/my_training_screen.dart';
import '../features/training/presentation/protocol_list_screen.dart';
import '../features/training/presentation/session_result_screen.dart';
import '../features/training/presentation/session_screen.dart';
import '../features/training/presentation/workout_builder_screen.dart';
import '../features/verification/presentation/admin_review_screen.dart';
import '../features/verification/presentation/credential_screen.dart';
import '../features/verification/presentation/guardian_link_screen.dart';
import '../features/verification/presentation/parent_consent_center_screen.dart';
import 'app_navigator.dart';
import 'config/app_environment.dart';
import 'diagnostics/diagnostic_runtime.dart';
import 'l10n/app_locale.dart';
import 'l10n/swan_localizations.dart';
import 'theme/theme_mode_controller.dart';
import 'update/update_gate.dart';
import 'widgets/page_transitions.dart';
import 'widgets/unavailable_feature_screen.dart';

class SwanSportApp extends ConsumerWidget {
  const SwanSportApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appEnvironmentProvider);

    return MaterialApp(
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      ),
      title: environment.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: swanNavigatorKey,
      navigatorObservers: [ref.watch(diagnosticNavigationObserverProvider)],
      scaffoldMessengerKey: swanMessengerKey,
      theme: SwanTheme.light().copyWith(
        pageTransitionsTheme: kSwanPageTransitions,
      ),
      darkTheme: SwanTheme.dark().copyWith(
        pageTransitionsTheme: kSwanPageTransitions,
      ),
      // Kullanıcının tercihi. Varsayılan `system` — uygulama bugüne kadar da
      // telefonun ayarını izliyordu; varsayılanı değiştirmek hiçbir tercih
      // yapmamış herkesin temasını bir güncellemede değiştirirdi.
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(appLocaleProvider).locale,
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        SwanLocalizations.delegate,
      ],
      builder: (context, child) =>
          AppUpdateGate(child: child ?? const SizedBox()),
      initialRoute: '/',
      routes: <String, WidgetBuilder>{
        '/': (context) => const AuthGate(),
        '/auth': (context) => const AuthScreen(),
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
        // push_route yedi mali bildirim türünü buraya yönlendiriyor.
        '/mali-isler': (context) => const FinanceTasksScreen(),
        '/kaydedilenler': (context) => const SavedPostsScreen(),
        '/yardim': (context) => const HelpScreen(),
        '/destek': (context) => const SupportScreen(),
        // 0071-0073. push_route 'training_session' ve 'training_result'
        // bildirimlerini buraya yonlendiriyor.
        '/antrenman-oturumu': (context) => const TrainingSessionScreen(),
        '/antrenman-sonuc': (context) => const SessionResultScreen(),
        '/antrenman-sablonlari': (context) => const ProtocolListScreen(),
        '/antrenman-olustur': (context) => const WorkoutProtocolBuilderScreen(),
        '/antrenmanlarim': (context) => const MyTrainingScreen(),
        '/dogrulama': (context) => const CredentialScreen(),
        '/veli-bagla': (context) => const GuardianLinkScreen(),
        '/onay-paneli': (context) => const AdminReviewScreen(),
        '/demo-rol': (context) =>
            ref.watch(appEnvironmentProvider).enableDebugTools
                ? const DemoRoleScreen()
                : const AuthScreen(),
        '/akis': (context) => const FeedScreen(),
        '/ara': (context) => const SearchScreen(),
        '/bildirimler': (context) => const NotificationsScreen(),
        '/mesajlar': (context) => const MessagesScreen(),
        '/topluluklar': (context) => const MessagesScreen(initialTab: 1),
        '/federasyon-takvimi': (context) => const PublicSportCalendarScreen(),
        '/kesfet': (context) => const ExploreScreen(),
        '/kulupler': (context) => const DiscoverScreen(),
        '/pazaryeri': (context) => const MarketplaceScreen(),
        '/antrenor-bul': (context) => const CoachDiscoveryScreen(),
        '/ilan-ver': (context) => const CreateListingScreen(),
        '/magaza-basvuru': (context) => const StoreApplicationScreen(),
        '/ilanlar': (context) => const ListingsScreen(),
        '/kortlar': (context) => const VenuesScreen(),
        '/oyuncu-aranan': (context) => const FindPartnerScreen(initialTab: 1),
        '/partner-ara': (context) => const FindPartnerScreen(),
        '/halisahalar': (context) => const VenuesScreen(initialTab: 1),
        '/organizasyonlar': (context) => const OrganizationsScreen(),
        '/finans': (context) => const FinanceScreen(),
        '/aidatlarim': (context) => const MyFeesScreen(),
        '/bagis': (context) => const CampaignsScreen(),
        '/federasyon-yetkili': (context) => const FederationAdminScreen(),
        '/haber-kaynaklari': (context) => const RssAdminScreen(),
        '/gizlilik': (context) => const PrivacyScreen(),
        '/devam-durumu': (context) => const AttendanceHistoryScreen(),
        '/basvurular': (context) => const ClubApplicationsScreen(),
        '/sezon-acilisi': (context) => const SeasonSetupScreen(),
        '/configuration': (context) =>
            environment.isProduction || ref.read(isSupabaseEnabledProvider)
                ? const UnavailableFeatureScreen(
                    title: 'Kulüp yapılandırması',
                    message:
                        'Bu gelişmiş yapılandırma ekranı henüz kullanıma açık değil. Kulüp profilini Ayarlar üzerinden düzenleyebilirsin.',
                    route: '/settings',
                    actionLabel: 'Ayarları aç',
                  )
                : const ConfigurationScreen(),
        '/facilities': (context) => const FacilityManagementScreen(),
        '/rezervasyon': (context) => const FacilityReservationScreen(),
        '/medical-center': (context) => const MedicalCenterScreen(),
        '/reports': (context) =>
            environment.isProduction || ref.read(isSupabaseEnabledProvider)
                ? const UnavailableFeatureScreen(
                    title: 'Raporlar',
                    message:
                        'Bu rapor arşivi henüz kullanıma açık değil. Mevcut mali kayıtlarını finans ekranından takip edebilirsin.',
                    route: '/finans',
                    actionLabel: 'Finansı aç',
                  )
                : const ReportsScreen(),
        '/performance-analytics': (context) =>
            const PerformanceAnalyticsScreen(),
        '/hazirbulunusluk': (context) => const ReadinessRpeScreen(),
        '/ekipman-tuning': (context) => const EquipmentTuningScreen(),
        '/veli-izinleri': (context) => const ParentConsentCenterScreen(),
        '/sepet': (context) => const CartCheckoutScreen(),
        '/musabaka-simulasyonu': (context) => const MatchSimulationScreen(),
        '/etkinlik-detay': (context) => const EventRosterDetailScreen(),
        '/ters-islem': (context) => const ClosedPeriodReversalScreen(),
        '/muhasebeci-defter': (context) =>
            const AccountantPrivacyLedgerScreen(),
        '/liderlik': (context) => const LeaderboardScreen(),
        '/beslenme': (context) => const NutritionTrackerScreen(),
        '/yaris-detay': (context) => const RaceEventDetailScreen(),
        '/kulup-detay': (context) => const ClubProfileDetailScreen(),
      }.map((route, builder) => MapEntry(route, SwanAccess.isGuestRoute(route)
          ? builder
          : (context) => AccountRouteGate(builder: builder))),
      onGenerateRoute: guardAccountRoutes((settings) {
        // These secondary design previews still use fixture repositories.
        // Preserve their URLs, but never expose fabricated records on a live backend.
        final previewRoute = settings.name;
        if ((environment.isProduction || ref.read(isSupabaseEnabledProvider)) &&
            (previewRoute == '/communication-detail' ||
                previewRoute == '/admin-user-detail' ||
                previewRoute == '/configuration-module' ||
                previewRoute == '/report-detail' ||
                (previewRoute?.startsWith('/performance-') ?? false))) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const UnavailableFeatureScreen(
              title: 'Ayrıntı görünümü kullanılamıyor',
              message:
                  'Bu ayrıntı görünümü henüz kullanıma açık değil. Kulübünün mevcut kayıtlarına yönetim ekranlarından ulaşabilirsin.',
              route: '/profil',
              actionLabel: 'Profil ve yönetime git',
            ),
          );
        }
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
        if (settings.name == '/saha-islemlerim') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SahaOperationsScreen(),
          );
        }
        if (settings.name == '/gelisim-raporu') {
          final args = settings.arguments;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => DevelopmentReportScreen(
              athleteId: args is Map && args['id'] is String
                  ? args['id'] as String
                  : null,
            ),
          );
        }
        if (settings.name == '/sporcu-performans') {
          final args = settings.arguments;
          final m = args is Map ? args : const <Object?, Object?>{};
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
          final m = args is Map ? args : const <Object?, Object?>{};
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
          final m = args is Map ? args : const <Object?, Object?>{};
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
          final m = args is Map ? args : const <Object?, Object?>{};
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
          final m = args is Map ? args : const <Object?, Object?>{};
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => CommunityChatScreen(
              communityId: '${m['id'] ?? ''}',
              title: '${m['name'] ?? 'Topluluk'}',
            ),
          );
        }
        if (settings.name == '/urun') {
          final args = settings.arguments;
          final m = args is Map ? args : const <Object?, Object?>{};
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => ListingDetailScreen(listingId: '${m['id'] ?? ''}'),
          );
        }
        if (settings.name == '/sohbet') {
          final args = settings.arguments;
          final m = args is Map ? args : const <Object?, Object?>{};
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
      }),
    );
  }
}
