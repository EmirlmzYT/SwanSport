import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_app.dart';
import 'package:swansport_pro/shell/pro_navigation.dart';
import 'package:swansport_pro/shell/pro_shell.dart';

class _FakeAccountSessionService implements AccountSessionService {
  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}
}

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
      email: 'usability@swansport.com',
    ),
  );
}

void main() {
  group('Pro Shell Usability Contracts', () {
    testWidgets('320px mobile viewport renders without any overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider
                .overrideWithValue(_FakeAccountSessionService()),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-shell-320')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            proUnreadNotificationsCountProvider.overrideWith((ref) async => 0),
          ],
          child: const ProApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProShell), findsOneWidget);
    });

    testWidgets(
        'shows unread notification badge on Gelen Kutusu when count > 0',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider
                .overrideWithValue(_FakeAccountSessionService()),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-shell-badge')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            proUnreadNotificationsCountProvider.overrideWith((ref) async => 3),
          ],
          child: const ProApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gelen Kutusu'), findsOneWidget);
      expect(find.text('3'), findsAtLeastNWidgets(1));
    });

    testWidgets('does not show fake count when unread count is 0',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider
                .overrideWithValue(_FakeAccountSessionService()),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-shell-nobadge')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            proUnreadNotificationsCountProvider.overrideWith((ref) async => 0),
          ],
          child: const ProApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gelen Kutusu'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('navigation items maintain >= 48x48 touch targets',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider
                .overrideWithValue(_FakeAccountSessionService()),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-shell-touch')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            proUnreadNotificationsCountProvider.overrideWith((ref) async => 0),
          ],
          child: const ProApp(),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Panel',
        'Görevler',
        'Takvim',
        'Gelen Kutusu',
        'Hesap'
      ]) {
        final target = find.widgetWithText(ProNavigationItem, label);
        expect(target, findsOneWidget);
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('renders cleanly under textScaler 1.3 without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(375 * 2, 812 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider
                .overrideWithValue(_FakeAccountSessionService()),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(_makeSession('user-shell-textscale')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            proUnreadNotificationsCountProvider.overrideWith((ref) async => 0),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.3),
            ),
            child: const ProApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProShell), findsOneWidget);
    });
  });
}
