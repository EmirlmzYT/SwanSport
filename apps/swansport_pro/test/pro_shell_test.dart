import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';
import 'package:swansport_pro/app/pro_app.dart';
import 'package:swansport_pro/features/account/pro_account_screen.dart';
import 'package:swansport_pro/features/auth/pro_login_screen.dart';
import 'package:swansport_pro/features/calendar/pro_calendar_screen.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro/features/operations/pro_tasks_screen.dart';
import 'package:swansport_pro/shell/pro_shell.dart';
import 'package:swansport_pro/workspaces/pro_workspace_switcher.dart';

class FakeAccountSessionService implements AccountSessionService {
  bool signOutCalled = false;

  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

Session makeSession(String userId, {String email = 'coach@swansport.com'}) {
  return Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-26',
      email: email,
    ),
  );
}

void main() {
  group('Pro Shell and Navigation', () {
    testWidgets('renders all five navigation destinations with exact labels',
        (tester) async {
      final fake = FakeAccountSessionService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(makeSession('user-1')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
          ],
          child: const ProApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProShell), findsOneWidget);
      expect(find.text('Panel'), findsAtLeastNWidgets(1));
      expect(find.text('Görevler'), findsOneWidget);
      expect(find.text('Takvim'), findsOneWidget);
      expect(find.text('Gelen Kutusu'), findsOneWidget);
      expect(find.text('Hesap'), findsOneWidget);
    });

    testWidgets('Panel and Hesap are functional; others show yakında',
        (tester) async {
      final fake = FakeAccountSessionService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(makeSession('user-1')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
          ],
          child: const ProApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Starts at /panel (ProDashboardScreen)
      expect(find.byType(ProDashboardScreen), findsOneWidget);

      // Tap Görevler
      await tester.tap(find.text('Görevler'));
      await tester.pumpAndSettle();
      expect(find.byType(ProTasksScreen), findsOneWidget);
      expect(find.text('Görevler & Aksiyon Kuyruğu'), findsOneWidget);

      // Tap Takvim
      await tester.tap(find.text('Takvim'));
      await tester.pumpAndSettle();
      expect(find.byType(ProCalendarScreen), findsOneWidget);

      // Tap Gelen Kutusu
      await tester.tap(find.text('Gelen Kutusu'));
      await tester.pumpAndSettle();
      expect(find.byType(SharedProInboxScreen), findsOneWidget);

      // Tap Hesap
      await tester.tap(find.text('Hesap'));
      await tester.pumpAndSettle();
      expect(find.byType(ProAccountScreen), findsOneWidget);
      expect(find.textContaining('coach@swansport.com'), findsOneWidget);
    });

    testWidgets('single workspace hides switching affordance', (tester) async {
      final fake = FakeAccountSessionService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(makeSession('user-1')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
          ],
          child: const ProApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Only 1 workspace (club) -> dropdown affordance should be hidden
      expect(find.byType(ProWorkspaceSwitcher), findsOneWidget);
      expect(find.byKey(const ValueKey('pro_workspace_dropdown_button')),
          findsNothing);
    });

    testWidgets(
        'multiple workspaces show switcher and selection updates dashboard',
        (tester) async {
      final fake = FakeAccountSessionService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(makeSession('user-1')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: true,
                clubRole: 'club_admin',
                coachLevel: 3,
                athleteKind: null,
              ),
            ),
          ],
          child: const ProApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pro_workspace_dropdown_button')),
          findsOneWidget);

      // Dashboard shows first workspace: Kulüp
      expect(find.textContaining('Kulüp'), findsAtLeastNWidgets(1));

      // Open switcher and select Antrenörlük
      await tester
          .tap(find.byKey(const ValueKey('pro_workspace_dropdown_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Antrenörlük').last);
      await tester.pumpAndSettle();

      // Dashboard updates to show Antrenörlük
      expect(find.textContaining('Antrenörlük'), findsAtLeastNWidgets(1));
    });

    testWidgets('logout from Account screen calls signOut and returns to login',
        (tester) async {
      final fake = FakeAccountSessionService();
      final sessions = StreamController<Session?>.broadcast();
      addTearDown(sessions.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
            authSessionProvider.overrideWith((ref) => sessions.stream),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: false,
                clubRole: 'club_admin',
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
          ],
          child: const ProApp(),
        ),
      );

      sessions.add(makeSession('user-1'));
      await tester.pumpAndSettle();

      // Go to Hesap
      await tester.tap(find.text('Hesap'));
      await tester.pumpAndSettle();

      // Click Çıkış Yap
      await tester.ensureVisible(find.text('Çıkış Yap'));
      await tester.tap(find.text('Çıkış Yap'));
      await tester.pumpAndSettle();

      expect(fake.signOutCalled, isTrue);

      // Session stream emits null
      sessions.add(null);
      await tester.pumpAndSettle();

      expect(find.byType(ProLoginScreen), findsOneWidget);
    });

    testWidgets('account change removes old user email and workspace state',
        (tester) async {
      final fake = FakeAccountSessionService();
      final sessions = StreamController<Session?>.broadcast();
      addTearDown(sessions.close);

      final accessState = StateProvider<SwanAccess>((ref) {
        return const SwanAccess(
          isPlatformAdmin: true,
          clubRole: 'club_admin',
          coachLevel: 0,
          athleteKind: null,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
            authSessionProvider.overrideWith((ref) => sessions.stream),
            swanAccessProvider.overrideWith((ref) => ref.watch(accessState)),
          ],
          child: const ProApp(),
        ),
      );

      sessions.add(makeSession('user-admin', email: 'admin@swansport.com'));
      await tester.pumpAndSettle();

      // Switch to Platform workspace
      await tester
          .tap(find.byKey(const ValueKey('pro_workspace_dropdown_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Platform').last);
      await tester.pumpAndSettle();

      // New user logs in with ONLY coaching access
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProApp)),
      );
      container.read(accessState.notifier).state = const SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'member',
        coachLevel: 2,
        athleteKind: null,
      );
      sessions.add(makeSession('user-coach', email: 'newcoach@swansport.com'));
      await tester.pumpAndSettle();

      // Platform workspace must NOT be retained! Current workspace must be Antrenörlük.
      expect(find.textContaining('Platform'), findsNothing);
      expect(find.textContaining('Antrenörlük'), findsAtLeastNWidgets(1));

      // Go to Hesap and check email is updated
      await tester.tap(find.text('Hesap'));
      await tester.pumpAndSettle();
      expect(find.text('newcoach@swansport.com'), findsOneWidget);
      expect(find.text('admin@swansport.com'), findsNothing);
    });
  });
}
