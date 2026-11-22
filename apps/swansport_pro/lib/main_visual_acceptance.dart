import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_theme.dart';
import 'package:swansport_pro/features/account/pro_account_screen.dart';
import 'package:swansport_pro/features/calendar/pro_calendar_screen.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro/features/inbox/pro_inbox_screen.dart';
import 'package:swansport_pro/features/operations/pro_club_management_screen.dart';
import 'package:swansport_pro/features/operations/pro_club_context_selector.dart';
import 'package:swansport_pro/features/operations/pro_feature_host.dart';
import 'package:swansport_pro/features/operations/pro_tasks_screen.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  final page = Uri.base.queryParameters['screen'] ?? 'panel';
  final isCredentialPage = page == 'credential-list';
  final today = calendarTurkeyTime(DateTime.now());
  runApp(
    ProviderScope(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => Stream.value(
            Session(
              accessToken: 'visual-only',
              tokenType: 'bearer',
              user: User(
                id: 'visual-user',
                appMetadata: const {},
                userMetadata: const {},
                aud: 'authenticated',
                createdAt: '2026-11-19',
                email: 'antrenor@swansport.local',
              ),
            ),
          ),
        ),
        swanAccessProvider.overrideWithValue(
          SwanAccess(
            isPlatformAdmin: isCredentialPage,
            clubRole: isCredentialPage ? null : 'coach',
            coachLevel: isCredentialPage ? 0 : 3,
            athleteKind: null,
          ),
        ),
        proAuthorizedClubsProvider.overrideWithValue(
          const AsyncData([
            ClubRef(id: 'club-1', name: 'Kadıköy Spor Kulübü', role: 'coach'),
          ]),
        ),
        activeClubProvider.overrideWith(
          (ref) async => const ClubRef(
            id: 'club-1',
            name: 'Kadıköy Spor Kulübü',
            role: 'coach',
          ),
        ),
        clubTodayAttendanceProvider.overrideWith(
          (ref) async => const ClubTodayAttendance(
            trainingCount: 3,
            markedCount: 1,
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.attendanceOperations,
            FeatureFlags.sportTrainingSessions,
          }),
        ),
        unifiedCalendarMonthProvider.overrideWith(
          (ref, month) async => UnifiedCalendarData([
            UnifiedCalendarEvent(
              id: 'club:training-1',
              title: 'Basketbol U16 Antrenmanı',
              type: CalendarEventType.clubTraining,
              startsAt: calendarDayStart(today).add(const Duration(hours: 18)),
              status: 'scheduled',
              place: 'Ana Salon',
            ),
          ]),
        ),
        proNotificationsProvider.overrideWith(
          (ref) async => const <NotificationRow>[],
        ),
        notificationPrefsProvider.overrideWith(
          (ref) async => const <NotificationPref>[],
        ),
        clubPendingApplicationsProvider.overrideWith(
          (ref) async => const <ClubApplicationRow>[],
        ),
        announcementsProvider.overrideWith(
          (ref) async => const <AnnouncementRow>[],
        ),
        clubDocumentsProvider.overrideWith(
          (ref) async => [
            DocumentRow(
              id: 'doc-1',
              name: '2026 Federasyon Tescil Belgesi',
              kind: 'pdf',
              sizeLabel: '1.2 MB',
              storagePath: 'club-1/tescil.pdf',
              version: 2,
              validUntil: DateTime(2027, 6, 30),
              createdAt: DateTime(2026, 11, 18),
            ),
            DocumentRow(
              id: 'doc-legacy',
              name: 'Eski Yönetim Kurulu Kararı',
              kind: 'file',
              createdAt: DateTime(2025, 3, 10),
            ),
          ],
        ),
        clubIdentityProvider.overrideWith((ref) async => null),
        pendingCredentialsProvider.overrideWith(
          (ref) async => const [
            CredentialRow(
              id: 'credential-1',
              kind: 'coach',
              status: 'pending',
              personName: 'Ayşe Yılmaz',
              sportCode: 'basketbol',
              sportName: 'Basketbol',
              coachLevel: 3,
            ),
            CredentialRow(
              id: 'credential-2',
              kind: 'athlete_licensed',
              status: 'pending',
              personName: 'Mehmet Kaya',
              sportCode: 'tenis',
              sportName: 'Tenis',
            ),
          ],
        ),
        sportlessCredentialsProvider.overrideWith((ref) async => const []),
        reviewLogProvider.overrideWith((ref) async => const []),
        credentialDocumentsProvider('credential-1').overrideWith(
          (ref) async => const [
            (
              docType: 'coach_certificate',
              url: 'https://signed.invalid/credential-1',
            ),
          ],
        ),
      ],
      child: _VisualAcceptanceApp(page: page),
    ),
  );
}

class _VisualAcceptanceApp extends StatelessWidget {
  const _VisualAcceptanceApp({required this.page});

  final String page;

  @override
  Widget build(BuildContext context) {
    final screen = switch (page) {
      'tasks' => const ProTasksScreen(),
      'calendar' => const ProCalendarScreen(),
      'inbox' => ProInboxScreen(onNotificationTap: (_) {}),
      'account' => const ProAccountScreen(),
      'documents' => const ProClubManagementScreen(initialTab: 2),
      'credential-list' => const ProOperationsFeatureHost(
          child: PlatformProfessionalReviewScreen(),
        ),
      _ => const ProDashboardScreen(),
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ProTheme.dark(),
      home: screen,
    );
  }
}
