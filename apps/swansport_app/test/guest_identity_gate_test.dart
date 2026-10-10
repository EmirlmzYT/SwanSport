import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/app/widgets/action_gate.dart';
import 'package:swansport_app/features/auth/presentation/screens/auth_gate.dart';
import 'package:swansport_app/features/clubs/presentation/club_apply_button.dart';
import 'package:swansport_app/features/network/presentation/guest_explore_screen.dart';
import 'package:swansport_app/features/verification/presentation/credential_screen.dart';
import 'package:swansport_app/features/social/presentation/feed_screen.dart';
import 'package:swansport_data/swansport_data.dart';

const account = SwanAccess(
    isPlatformAdmin: false, clubRole: null, coachLevel: 0, athleteKind: null);
const verified = SwanAccess(
    isPlatformAdmin: false,
    clubRole: null,
    coachLevel: 0,
    athleteKind: null,
    hasVerifiedIdentity: true);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Widget host(Widget child, {SwanAccess access = SwanAccess.none}) =>
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(access),
          newsProvider.overrideWith((ref) async => []),
          onboardingSeenProvider.overrideWith((ref) async => true),
          myClubsProvider.overrideWith((ref) async => []),
          myApplicationsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(home: child, routes: {
          '/auth': (_) => const Scaffold(body: Text('AUTH TARGET')),
          '/dogrulama': (_) => const Scaffold(body: Text('CREDENTIAL TARGET')),
          '/kesfet': (_) => const GuestExploreScreen(),
        }),
      );

  testWidgets(
      'anonymous startup opens public discovery without private feed reads',
      (tester) async {
    await tester.pumpWidget(host(const AuthGate()));
    await tester.pumpAndSettle();
    expect(find.byType(GuestExploreScreen), findsOneWidget);
    expect(find.text('Federasyon Faaliyet Takvimi'), findsOneWidget);
    await tester.tap(find.text('Giriş Yap / Kayıt Ol'));
    await tester.pumpAndSettle();
    expect(find.text('AUTH TARGET'), findsOneWidget);
  });

  testWidgets(
      'an existing session still opens FeedScreen and sign-out returns to discovery',
      (tester) async {
    final sessions = StreamController<Session?>();
    addTearDown(sessions.close);
    await tester.pumpWidget(ProviderScope(overrides: [
      authSessionProvider.overrideWith((ref) => sessions.stream),
      swanAccessProvider.overrideWithValue(account),
      onboardingSeenProvider.overrideWith((ref) async => true),
    ], child: const MaterialApp(home: AuthGate())));
    sessions.add(Session(
        accessToken: 'test',
        tokenType: 'bearer',
        user: User(
            id: 'account',
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-10T00:00:00Z')));
    await tester.pumpAndSettle();
    expect(find.byType(FeedScreen), findsOneWidget);
    sessions.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(GuestExploreScreen), findsOneWidget);
    expect(find.byType(FeedScreen), findsNothing);
  });

  testWidgets(
      'guest discovery and login sheet fit a narrow dark screen with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!),
      home: const GuestExploreScreen(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Bu özelliği kullanabilmek için hesap açmalısınız'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final action in SwanAction.values) {
    testWidgets('guest $action is blocked before invoking its write',
        (tester) async {
      var writes = 0;
      await tester.pumpWidget(host(Consumer(
          builder: (context, ref, _) => Scaffold(
                body: FilledButton(
                    onPressed: () async {
                      if (await requireSwanAction(context, ref, action))
                        writes++;
                    },
                    child: const Text('ACTION')),
              ))));
      await tester.tap(find.text('ACTION'));
      await tester.pumpAndSettle();
      expect(find.text('Bu özelliği kullanabilmek için hesap açmalısınız'),
          findsOneWidget);
      expect(writes, 0);
      await tester.tap(find.text('Gezintiye devam et'));
      await tester.pumpAndSettle();
      expect(writes, 0);
    });
  }

  testWidgets(
      'unverified club applicant is directed to credentials before form/service',
      (tester) async {
    await tester.pumpWidget(host(
        const Scaffold(body: ClubApplyButton(clubId: 'club', clubName: 'Club')),
        access: account));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kulübe Başvur'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Resmi kulüp kadrosuna katılmak için kimlik/lisans doğrulamanız gerekmektedir'),
        findsOneWidget);
    expect(find.text('Başvuruyu Gönder'), findsNothing);
    await tester.tap(find.text('Kimlik ve belge yükle'));
    await tester.pumpAndSettle();
    expect(find.text('CREDENTIAL TARGET'), findsOneWidget);
  });

  testWidgets('verified club applicant retains athlete and coach form choices',
      (tester) async {
    await tester.pumpWidget(host(
        const Scaffold(body: ClubApplyButton(clubId: 'club', clubName: 'Club')),
        access: verified));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kulübe Başvur'));
    await tester.pumpAndSettle();
    expect(find.text('Sporcu'), findsOneWidget);
    expect(find.text('Antrenör'), findsOneWidget);
    expect(find.text('Başvuruyu Gönder'), findsOneWidget);
  });

  testWidgets(
      'private route never constructs child while guest and reacts to account changes',
      (tester) async {
    var constructed = 0;
    final container = ProviderContainer(
        overrides: [swanAccessProvider.overrideWithValue(SwanAccess.none)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: AccountRouteGate(builder: (_) {
          constructed++;
          return const Scaffold(body: Text('PRIVATE'));
        }))));
    expect(constructed, 0);
    container.updateOverrides([swanAccessProvider.overrideWithValue(account)]);
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE'), findsOneWidget);
    container.updateOverrides(
        [swanAccessProvider.overrideWithValue(SwanAccess.none)]);
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE'), findsNothing);
  });

  testWidgets(
      'named and generated private deep links reject guests; public calendar stays readable',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      swanAccessProvider.overrideWithValue(SwanAccess.none),
      onboardingSeenProvider.overrideWith((ref) async => true),
    ], child: const SwanSportApp()));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    for (final route in ['/ilan-ver', '/sohbet', '/dogrulama', '/resmi-sonuc?notification=private']) {
      unawaited(nav.pushNamed(route));
      await tester.pumpAndSettle();
      expect(find.text('Bu özelliği kullanabilmek için hesap açmalısınız'),
          findsOneWidget);
      nav.pop();
      await tester.pumpAndSettle();
    }
    unawaited(nav.pushNamed('/federasyon-takvimi'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz etkinlik yok'), findsOneWidget);
  });

  testWidgets(
      'credential screen starts with identity and collects sport expiry',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(const CredentialScreen(), access: account));
    await tester.pumpAndSettle();
    expect(find.text('Kimlik Belgesi'), findsOneWidget);
    await tester.tap(find.text('Sporcu'));
    await tester.pumpAndSettle();
    expect(find.text('Bitiş tarihi seç'), findsOneWidget);
    expect(find.text('Federasyon Lisansı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
