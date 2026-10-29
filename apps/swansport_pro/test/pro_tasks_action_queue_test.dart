import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro/features/operations/pro_club_context_selector.dart';
import 'package:swansport_pro/features/operations/pro_tasks_screen.dart';
import 'package:swansport_pro/widgets/pro_ui_components.dart';
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
      email: 'tasks@swansport.com',
    ),
  );
}

void main() {
  group('Pro Tasks Action Queue Contracts', () {
    testWidgets('Panel and Görevler do NOT show identical card lists',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-diff-screens')),
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
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.coachWorkspace,
                FeatureFlags.attendanceOperations,
                FeatureFlags.teamHub,
              }),
            ),
          ],
          child: const MaterialApp(
            home: Column(
              children: [
                Expanded(child: ProDashboardScreen()),
                Expanded(child: ProTasksScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ProTasksScreen must be an action queue rather than duplicating the entire
      // SharedClubOperationsPanel directly inside itself.
      expect(find.byType(ProDashboardScreen), findsOneWidget);
      expect(find.byType(ProTasksScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProDashboardScreen),
          matching: find.byType(SharedClubOperationsPanel),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProTasksScreen),
          matching: find.byType(SharedClubOperationsPanel),
        ),
        findsNothing,
      );

      // Verify that ProTasksScreen contains filter bar and no duplicate operations panel
      expect(
        find.descendant(
          of: find.byType(ProTasksScreen),
          matching: find.byType(ProFilterBar),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProTasksScreen),
          matching: find.byWidgetPredicate((widget) =>
              widget is Text &&
              (widget.data == 'Tümü' || widget.data == 'Bekleyen')),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('empty state displays friendly message with next action',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-tasks-empty')),
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
          ],
          child: const MaterialApp(
            home: ProTasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('görev'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });
  });
}
