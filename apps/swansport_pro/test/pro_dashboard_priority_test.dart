import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
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
      email: 'dashboard@swansport.com',
    ),
  );
}

void main() {
  group('Pro Dashboard Priority & Today Hub Contracts', () {
    testWidgets(
        'compact header shows active workspace and no redundant Aktif badge',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-dash-header')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            proAuthorizedClubsProvider.overrideWith(
              (ref) async => [
                const ClubRef(
                    id: 'club-1', name: 'Kadıköy SK', role: 'club_admin'),
              ],
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
            home: ProDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProDashboardScreen), findsOneWidget);
      expect(find.text('Kulüp Paneli'), findsOneWidget);
      // Generic standalone "Aktif" chip removed in favor of compact scope/refresh
      expect(find.text('Aktif'), findsNothing);
    });

    testWidgets(
        '390px mobile viewport keeps first priority task above the fold',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-fold-390')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            proAuthorizedClubsProvider.overrideWith(
              (ref) async => [
                const ClubRef(
                    id: 'club-1', name: 'Kadıköy SK', role: 'club_admin'),
              ],
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
                FeatureFlags.coachWorkspace: 'everyone',
                FeatureFlags.attendanceOperations: 'everyone',
                FeatureFlags.teamHub: 'everyone',
              }),
            ),
          ],
          child: const MaterialApp(
            home: ProDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstTask = find.text('Bugün').or(find.text('Öncelikli İşlemler'));
      expect(firstTask, findsAtLeastNWidgets(1));

      final firstTaskPos = tester.getTopLeft(firstTask.first);
      // Must be above the fold (within screen height 844)
      expect(firstTaskPos.dy, lessThan(600.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'referee workspace renders Today section with pending assignments',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-referee-dash')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
                isReferee: true,
              ),
            ),
            selectedProWorkspaceProvider.overrideWith(
              (ref) => ProWorkspace.referee,
            ),
            featureFlagsProvider.overrideWith(
              (ref) async => const FeatureFlags({
                FeatureFlags.refereeCockpit: 'everyone',
              }),
            ),
          ],
          child: const MaterialApp(
            home: ProDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SharedRefereeOperationsPanel), findsOneWidget);
    });
  });
}
