import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/auth/pro_auth_controller.dart';
import 'package:swansport_pro/features/auth/pro_auth_gate.dart';
import 'package:swansport_pro/features/auth/pro_login_screen.dart';

class FakeAccountSessionService implements AccountSessionService {
  FakeAccountSessionService({this.events});

  final List<String>? events;
  String? lastEmail;
  String? lastPassword;
  bool shouldFail = false;
  String failureMessage = 'Hatalı kullanıcı adı veya şifre';
  bool signOutCalled = false;

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
    if (shouldFail) {
      throw AuthException(failureMessage);
    }
  }

  @override
  Future<void> signOut() async {
    events?.add('sign-out');
    signOutCalled = true;
  }
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
    ),
  );
}

void main() {
  group('ProAuthController', () {
    test('validates empty email and password', () async {
      final fake = FakeAccountSessionService();
      final container = ProviderContainer(
        overrides: [accountSessionServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(proAuthControllerProvider.notifier);

      final resultEmptyEmail = await controller.signIn('', 'password123');
      expect(resultEmptyEmail, isFalse);
      expect(
        container.read(proAuthControllerProvider).errorMessage,
        contains('E-posta'),
      );

      final resultEmptyPass = await controller.signIn('user@test.com', '');
      expect(resultEmptyPass, isFalse);
      expect(
        container.read(proAuthControllerProvider).errorMessage,
        contains('Şifre'),
      );
    });

    test(
      'localizes invalid credentials without exposing backend detail',
      () async {
        final fake = FakeAccountSessionService()
          ..shouldFail = true
          ..failureMessage = 'Invalid login credentials';
        final container = ProviderContainer(
          overrides: [accountSessionServiceProvider.overrideWithValue(fake)],
        );
        addTearDown(container.dispose);

        final controller = container.read(proAuthControllerProvider.notifier);
        final success = await controller.signIn('user@test.com', 'wrong-pass');

        expect(success, isFalse);
        expect(
          container.read(proAuthControllerProvider).errorMessage,
          equals('E-posta adresi veya şifre hatalı.'),
        );
        expect(
          container.read(proAuthControllerProvider).errorMessage,
          isNot(contains('Invalid login credentials')),
        );
      },
    );

    test('does not expose unknown authentication details', () async {
      final fake = FakeAccountSessionService()
        ..shouldFail = true
        ..failureMessage = 'private authentication detail';
      final container = ProviderContainer(
        overrides: [accountSessionServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(proAuthControllerProvider.notifier)
          .signIn('user@test.com', 'wrong-pass');

      expect(success, isFalse);
      expect(
        container.read(proAuthControllerProvider).errorMessage,
        equals('Giriş yapılamadı. Bilgilerini kontrol edip tekrar dene.'),
      );
      expect(
        container.read(proAuthControllerProvider).errorMessage,
        isNot(contains('private')),
      );
    });

    test('delegates successful signIn and clears error', () async {
      final fake = FakeAccountSessionService();
      final container = ProviderContainer(
        overrides: [accountSessionServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(proAuthControllerProvider.notifier);
      final success = await controller.signIn('user@test.com', 'secret123');

      expect(success, isTrue);
      expect(fake.lastEmail, equals('user@test.com'));
      expect(fake.lastPassword, equals('secret123'));
      expect(container.read(proAuthControllerProvider).errorMessage, isNull);
    });

    test('delegates signOut to AccountSessionService', () async {
      final fake = FakeAccountSessionService();
      final container = ProviderContainer(
        overrides: [accountSessionServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final controller = container.read(proAuthControllerProvider.notifier);
      await controller.signOut();
      expect(fake.signOutCalled, isTrue);
    });

    test(
      'removes the Pro push subscription before ending the session',
      () async {
        final events = <String>[];
        final fake = FakeAccountSessionService(events: events);
        final controller = ProAuthController(
          fake,
          beforeSignOut: () async => events.add('push-cleanup'),
        );

        await controller.signOut();

        expect(events, equals(['push-cleanup', 'sign-out']));
      },
    );

    test('still signs out when push cleanup fails', () async {
      final events = <String>[];
      final fake = FakeAccountSessionService(events: events);
      final controller = ProAuthController(
        fake,
        beforeSignOut: () async {
          events.add('push-cleanup');
          throw StateError('network');
        },
      );

      await controller.signOut();

      expect(events, equals(['push-cleanup', 'sign-out']));
      expect(fake.signOutCalled, isTrue);
    });
  });

  group('ProLoginScreen', () {
    testWidgets('renders email/password fields and handles submission', (
      tester,
    ) async {
      final fake = FakeAccountSessionService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [accountSessionServiceProvider.overrideWithValue(fake)],
          child: const MaterialApp(home: ProLoginScreen()),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Giriş Yap'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'pro@test.com');
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();

      expect(fake.lastEmail, equals('pro@test.com'));
      expect(fake.lastPassword, equals('secret'));
    });
  });

  group('ProAuthGate', () {
    testWidgets('shows loading when authSessionProvider is loading', (
      tester,
    ) async {
      final sessions = StreamController<Session?>();
      addTearDown(sessions.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionProvider.overrideWith((ref) => sessions.stream),
          ],
          child: const MaterialApp(
            home: ProAuthGate(child: Text('PRO_CONTENT')),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('PRO_CONTENT'), findsNothing);
    });

    testWidgets('shows ProLoginScreen when signed out', (tester) async {
      final fake = FakeAccountSessionService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
            authSessionProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: ProAuthGate(child: Text('PRO_CONTENT')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProLoginScreen), findsOneWidget);
      expect(find.text('PRO_CONTENT'), findsNothing);
    });

    testWidgets(
      'shows no-pro-access screen when signed in without professional access',
      (tester) async {
        final fake = FakeAccountSessionService();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountSessionServiceProvider.overrideWithValue(fake),
              authSessionProvider.overrideWith(
                (ref) => Stream.value(makeSession('user-no-pro')),
              ),
              swanAccessProvider.overrideWithValue(SwanAccess.none),
            ],
            child: const MaterialApp(
              home: ProAuthGate(child: Text('PRO_CONTENT')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PRO_CONTENT'), findsNothing);
        expect(find.textContaining('yetki bulunamadı'), findsOneWidget);

        final logoutBtn = find.text('Çıkış Yap');
        expect(logoutBtn, findsOneWidget);
        await tester.tap(logoutBtn);
        await tester.pumpAndSettle();

        expect(fake.signOutCalled, isTrue);
      },
    );

    testWidgets(
      'keeps a neutral loading state while professional access inputs load',
      (tester) async {
        final fake = FakeAccountSessionService();
        final profile = Completer<ProfileInfo?>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              accountSessionServiceProvider.overrideWithValue(fake),
              authSessionProvider.overrideWith(
                (ref) => Stream.value(makeSession('user-loading-access')),
              ),
              currentProfileProvider.overrideWith((ref) => profile.future),
            ],
            child: const MaterialApp(
              home: ProAuthGate(child: Text('PRO_CONTENT')),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Profesyonel Erişim Bulunamadı'), findsNothing);
        expect(find.text('PRO_CONTENT'), findsNothing);
      },
    );

    testWidgets(
      'shows child when signed in with authorized professional access',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authSessionProvider.overrideWith(
                (ref) => Stream.value(makeSession('user-admin')),
              ),
              swanAccessProvider.overrideWithValue(
                const SwanAccess(
                  isPlatformAdmin: true,
                  clubRole: null,
                  coachLevel: 0,
                  athleteKind: null,
                ),
              ),
            ],
            child: const MaterialApp(
              home: ProAuthGate(child: Text('PRO_CONTENT')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('PRO_CONTENT'), findsOneWidget);
      },
    );

    testWidgets('account changes invalidate cached shared access inputs', (
      tester,
    ) async {
      final sessions = StreamController<Session?>.broadcast();
      addTearDown(sessions.close);
      final fake = FakeAccountSessionService();
      var adminReads = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountSessionServiceProvider.overrideWithValue(fake),
            authSessionProvider.overrideWith((ref) => sessions.stream),
            currentProfileProvider.overrideWith(
              (ref) async =>
                  const ProfileInfo(id: 'profile', fullName: 'Test User'),
            ),
            isPlatformAdminProvider.overrideWith((ref) async {
              adminReads++;
              return true;
            }),
          ],
          child: const MaterialApp(
            home: ProAuthGate(child: Text('PRO_CONTENT')),
          ),
        ),
      );

      sessions.add(makeSession('user-one'));
      await tester.pumpAndSettle();
      expect(find.text('PRO_CONTENT'), findsOneWidget);
      final readsAfterFirstAccount = adminReads;
      expect(readsAfterFirstAccount, greaterThan(0));

      sessions.add(makeSession('user-two'));
      await tester.pumpAndSettle();

      expect(adminReads, greaterThan(readsAfterFirstAccount));
      expect(find.text('PRO_CONTENT'), findsOneWidget);
    });
  });

  group('Pro source contracts', () {
    test('Pro widgets contain no direct Supabase query calls', () {
      final proDir = Directory('lib').existsSync()
          ? Directory('lib')
          : Directory('apps/swansport_pro/lib');
      final dartFiles = proDir.listSync(recursive: true).whereType<File>();

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(
          content.contains('.from('),
          isFalse,
          reason: '${file.path} must not call .from()',
        );
        expect(
          content.contains('.rpc('),
          isFalse,
          reason: '${file.path} must not call .rpc()',
        );
        expect(
          content.contains('Supabase.instance.client.auth'),
          isFalse,
          reason: '${file.path} must not call Supabase client directly',
        );
      }
    });
  });
}
