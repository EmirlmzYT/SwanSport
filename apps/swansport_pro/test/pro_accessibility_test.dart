import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_app.dart';
import 'package:swansport_pro/shell/pro_navigation.dart';

class FakeAccountSessionService implements AccountSessionService {
  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}
}

Session makeSession(String userId) {
  return Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-26',
      email: 'pro@swansport.com',
    ),
  );
}

void main() {
  group('Pro Accessibility and Responsiveness', () {
    testWidgets('renders without overflow at 320px width and text scale 2.0',
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
            accountSessionServiceProvider.overrideWithValue(FakeAccountSessionService()),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(makeSession('user-a11y')),
            ),
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: true,
                clubRole: 'club_admin',
                coachLevel: 2,
                athleteKind: null,
              ),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2.0),
            ),
            child: const ProApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('navigation destinations have at least 48x48 hit areas and semantic labels',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(FakeAccountSessionService()),
            authSessionProvider.overrideWith(
              (ref) => Stream.value(makeSession('user-a11y')),
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

      for (final label in ['Panel', 'Görevler', 'Takvim', 'Gelen Kutusu', 'Hesap']) {
        final target = find.widgetWithText(ProNavigationItem, label);
        expect(target, findsOneWidget);
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });
  });
}
