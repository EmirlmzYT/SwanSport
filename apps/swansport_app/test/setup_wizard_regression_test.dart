import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/design/swan_palette.dart';
import 'package:swansport_app/app/widgets/swan_tabs.dart';
import 'package:swansport_app/features/auth/presentation/screens/auth_gate.dart';
import 'package:swansport_app/features/onboarding/application/setup_wizard_progress.dart';
import 'package:swansport_app/features/onboarding/presentation/setup_wizard_screen.dart';
import 'package:swansport_app/features/verification/presentation/credential_screen.dart';
import 'package:swansport_data/swansport_data.dart';

const _account = SwanAccess(
  isPlatformAdmin: false, clubRole: null, coachLevel: 0, athleteKind: null,
);
const _verified = SwanAccess(
  isPlatformAdmin: false, clubRole: null, coachLevel: 0, athleteKind: null,
  hasVerifiedIdentity: true,
);

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> advance(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Devam Et'));
    await tester.pumpAndSettle();
  }

  for (final verified in [false, true]) {
    testWidgets('guardian follows server identity axis: verified=$verified', (tester) async {
      RouteSettings? destination;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(verified ? _verified : _account),
          authSessionProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          home: const SetupWizardScreen(),
          onGenerateRoute: (settings) {
            destination = settings;
            return MaterialPageRoute<void>(settings: settings,
              builder: (_) => const Scaffold(body: Text('TARGET')));
          },
        ),
      ));
      await tester.pumpAndSettle();
      await advance(tester);
      await tester.ensureVisible(find.text('Sporcu Velisiyim'));
      await tester.tap(find.text('Sporcu Velisiyim'));
      await tester.pumpAndSettle();
      await advance(tester);
      await advance(tester);
      await advance(tester);
      final label = verified ? 'Davet Kodunu Gir' : 'Kimlik Belgesi Yükle';
      await tester.tap(find.widgetWithText(ElevatedButton, label).last);
      await tester.pumpAndSettle();
      expect(destination?.name, verified ? '/veli-bagla' : '/dogrulama');
      expect(destination?.arguments, verified ? isNull : 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending registration opens guide on confirmed-session startup', (tester) async {
    await queueSetupWizard('new-account');
    final session = Session(accessToken: 'test', tokenType: 'bearer',
      user: User(id: 'new-account', appMetadata: {}, userMetadata: {},
        aud: 'authenticated', createdAt: '2026-10-11T00:00:00Z'));
    await tester.pumpWidget(ProviderScope(overrides: [
      authSessionProvider.overrideWith((ref) => Stream.value(session)),
      swanAccessProvider.overrideWithValue(_account),
    ], child: const MaterialApp(home: AuthGate())));
    await tester.pumpAndSettle();
    expect(find.byType(SetupWizardScreen), findsOneWidget);
  });

  testWidgets('route initial mode does not overwrite user tab on theme change', (tester) async {
    final dark = ValueNotifier(false);
    addTearDown(dark.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      swanAccessProvider.overrideWithValue(_account),
      myCredentialsProvider.overrideWith((ref) async => []),
    ], child: ValueListenableBuilder<bool>(valueListenable: dark,
      builder: (_, value, __) => MaterialApp(
        theme: value ? ThemeData.dark() : ThemeData.light(),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/', arguments: 1),
          builder: (_) => const CredentialScreen()),
      ),
    )));
    await tester.pumpAndSettle();
    expect(tester.widget<SwanSegmentedTabs>(find.byType(SwanSegmentedTabs)).selected, 1);
    await tester.tap(find.text('Kimlik'));
    await tester.pumpAndSettle();
    dark.value = true;
    await tester.pumpAndSettle();
    expect(tester.widget<SwanSegmentedTabs>(find.byType(SwanSegmentedTabs)).selected, 2);
    await tester.scrollUntilVisible(find.text('Kimlik Belgesi'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Kimlik Belgesi'), findsOneWidget);
    expect(find.text('Federasyon Lisansı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark guide primary button uses fill token', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      swanAccessProvider.overrideWithValue(_account),
    ], child: MaterialApp(theme: ThemeData.dark(), home: const SetupWizardScreen())));
    await tester.pumpAndSettle();
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Devam Et'));
    expect(button.style!.backgroundColor!.resolve({}), SwanPalette.dark.accentFill);
  });
}
