import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/operations/pro_feature_host.dart';
import 'package:swansport_pro/workspaces/pro_workspace.dart';
import 'package:swansport_pro/workspaces/pro_workspace_controller.dart';
import 'package:swansport_pro/workspaces/pro_workspace_switcher.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

Session _makeSession({
  required String userId,
  Map<String, dynamic> appMetadata = const {},
  Map<String, dynamic> userMetadata = const {},
}) {
  return Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: appMetadata,
      userMetadata: userMetadata,
      aud: 'authenticated',
      createdAt: '2026-10-26',
      email: 'switcher@swansport.com',
    ),
  );
}

void main() {
  group('Pro Workspace Switcher Usability & Security Contracts', () {
    testWidgets('single workspace hides switching dropdown button',
        (tester) async {
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
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession(userId: 'user-single')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ProWorkspaceSwitcher()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pro_workspace_dropdown_button')),
          findsNothing);
      expect(find.text('Kulüp'), findsOneWidget);
    });

    testWidgets('multiple workspaces show switcher and open accessible modal',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: true,
              clubRole: 'club_admin',
              coachLevel: 0,
              athleteKind: null,
            ),
          ),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession(userId: 'user-multi')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProOperationsFeatureHost(
              child: Scaffold(body: ProWorkspaceSwitcher()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button =
          find.byKey(const ValueKey('pro_workspace_dropdown_button'));
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Çalışma Alanı Değiştir'), findsAtLeastNWidgets(1));
      expect(find.text('Kulüp'), findsAtLeastNWidgets(1));
      expect(find.text('Platform'), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'switching workspace triggers dirty form guard and clears scope',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: true,
              clubRole: 'club_admin',
              coachLevel: 0,
              athleteKind: null,
            ),
          ),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(_makeSession(userId: 'user-dirty-switch')),
          ),
        ],
      );
      addTearDown(container.dispose);

      final registration =
          container.read(proDirtyStateCoordinatorProvider).register('fixture');
      registration.markDirty();
      addTearDown(registration.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ProOperationsFeatureHost(
              child: Scaffold(body: ProWorkspaceSwitcher()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(selectedProWorkspaceProvider), ProWorkspace.club);

      await tester
          .tap(find.byKey(const ValueKey('pro_workspace_dropdown_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Platform').last);
      await tester.pumpAndSettle();

      expect(find.text('Kaydedilmemiş değişiklikler var'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(container.read(selectedProWorkspaceProvider), ProWorkspace.club);

      await tester
          .tap(find.byKey(const ValueKey('pro_workspace_dropdown_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Platform').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alanı değiştir'));
      await tester.pumpAndSettle();

      expect(
          container.read(selectedProWorkspaceProvider), ProWorkspace.platform);
      expect(container.read(selectedClubIdProvider), isNull);
    });

    test('user_metadata CANNOT grant any preview workspace access', () {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(SwanAccess.none),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              _makeSession(
                userId: 'user-attacker',
                userMetadata: {
                  'pro_preview': true,
                  'preview': true,
                  'role': 'platform_admin',
                  'is_platform_admin': true,
                  'workspaces': ['platform', 'club'],
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final workspaces = container.read(availableProWorkspacesProvider);
      expect(workspaces, isEmpty,
          reason:
              'user_metadata is client-writable and must never grant access');
      expect(container.read(selectedProWorkspaceProvider), isNull);
    });

    test('server-controlled app_metadata preview works as expected', () {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(SwanAccess.none),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              _makeSession(
                userId: 'user-preview-qa',
                appMetadata: {
                  'pro_preview_workspaces': ['club', 'platform'],
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final workspaces = container.read(availableProWorkspacesProvider);
      expect(
          workspaces, containsAll([ProWorkspace.club, ProWorkspace.platform]),
          reason: 'server-controlled app_metadata preview should be honored');
    });
  });
}
