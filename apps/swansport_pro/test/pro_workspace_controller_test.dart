import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/workspaces/pro_workspace.dart';
import 'package:swansport_pro/workspaces/pro_workspace_controller.dart';

void main() {
  SwanAccess makeAccess({
    bool isPlatformAdmin = false,
    String? clubRole,
    int coachLevel = 0,
    Set<String> accountantClubIds = const {},
  }) {
    return SwanAccess(
      isPlatformAdmin: isPlatformAdmin,
      clubRole: clubRole,
      coachLevel: coachLevel,
      athleteKind: null,
      accountantClubIds: accountantClubIds,
    );
  }

  Session makeSession(
    String userId, {
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
      ),
    );
  }

  group('selectedProWorkspaceProvider', () {
    test('server-controlled developer preview exposes every workspace',
        () async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(SwanAccess.none),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              makeSession(
                'developer-1',
                appMetadata: const {'pro_workspace_preview': true},
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authSessionProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(availableProWorkspacesProvider),
        equals(ProWorkspace.values),
      );
      expect(
        container.read(selectedProWorkspaceProvider),
        equals(ProWorkspace.club),
      );
    });

    test('developer preview fails closed for missing or malformed metadata',
        () {
      for (final metadata in <Map<String, dynamic>>[
        const {},
        const {'pro_workspace_preview': 'true'},
        const {'pro_workspace_preview': false},
      ]) {
        final container = ProviderContainer(
          overrides: [
            swanAccessProvider.overrideWithValue(SwanAccess.none),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(
                makeSession('user-1', appMetadata: metadata),
              ),
            ),
          ],
        );

        expect(container.read(availableProWorkspacesProvider), isEmpty);
        container.dispose();
      }
    });

    test('user-controlled metadata cannot enable developer preview', () async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(SwanAccess.none),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(
              makeSession(
                'user-1',
                userMetadata: const {'pro_workspace_preview': true},
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authSessionProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      expect(container.read(availableProWorkspacesProvider), isEmpty);
    });

    test('becomes null when user has no professional access', () {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(SwanAccess.none),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(makeSession('user-1')),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedProWorkspaceProvider), isNull);
    });

    test('auto-selects the sole workspace when exactly one is available', () {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            makeAccess(clubRole: 'club_admin'),
          ),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(makeSession('user-1')),
          ),
        ],
      );
      addTearDown(container.dispose);

      final workspaces = container.read(availableProWorkspacesProvider);
      expect(workspaces, equals([ProWorkspace.club]));
      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.club));
    });

    test('defaults to the first workspace when multiple are available', () {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            makeAccess(
              clubRole: 'club_admin',
              coachLevel: 2,
              isPlatformAdmin: true,
            ),
          ),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(makeSession('user-1')),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.club));
    });

    test('preserves valid manual selection across reads', () {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            makeAccess(
              clubRole: 'club_admin',
              isPlatformAdmin: true,
            ),
          ),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(makeSession('user-1')),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.club));

      container
          .read(selectedProWorkspaceProvider.notifier)
          .selectWorkspace(ProWorkspace.platform);
      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.platform));
    });

    test('resets to the first available workspace if current selection is lost',
        () {
      final accessState = StateProvider<SwanAccess>((ref) {
        return makeAccess(
          clubRole: 'club_admin',
          isPlatformAdmin: true,
        );
      });

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWith((ref) => ref.watch(accessState)),
          authSessionProvider.overrideWith(
            (ref) => Stream.value(makeSession('user-1')),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(selectedProWorkspaceProvider.notifier)
          .selectWorkspace(ProWorkspace.platform);
      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.platform));

      // User loses platform admin access
      container.read(accessState.notifier).state =
          makeAccess(clubRole: 'club_admin');

      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.club));
    });

    test('resets selection when session/account changes', () async {
      final sessions = StreamController<Session?>();
      addTearDown(sessions.close);

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            makeAccess(
              clubRole: 'club_admin',
              isPlatformAdmin: true,
            ),
          ),
          authSessionProvider.overrideWith((ref) => sessions.stream),
        ],
      );
      addTearDown(container.dispose);

      container.listen(selectedProWorkspaceProvider, (_, __) {});
      sessions.add(makeSession('user-1'));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.club));

      container
          .read(selectedProWorkspaceProvider.notifier)
          .selectWorkspace(ProWorkspace.platform);
      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.platform));

      // User signs out / switches account
      sessions.add(makeSession('user-2'));
      await Future<void>.delayed(Duration.zero);

      // New account defaults back to first available workspace
      expect(container.read(selectedProWorkspaceProvider),
          equals(ProWorkspace.club));
    });
  });
}
