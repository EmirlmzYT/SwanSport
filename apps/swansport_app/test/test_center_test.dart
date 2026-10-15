import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/app/config/app_environment.dart';
import 'package:swansport_app/features/test_center/test_center_screen.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('opt-in, development, debug and local endpoint are all required', () {
    for (final env in [const AppEnvironment.production(), const AppEnvironment.development()]) {
      for (final enabled in [false, true]) {
        for (final url in ['http://127.0.0.1:55421', 'https://api.swansport.com.tr']) {
          final container = ProviderContainer(overrides: [
            appEnvironmentProvider.overrideWithValue(env),
            localTestCenterRequestedProvider.overrideWithValue(enabled),
            supabaseConfigProvider.overrideWithValue(SupabaseConfig(url: url, anonKey: 'public')),
          ]);
          expect(container.read(localTestCenterEnabledProvider),
              enabled && env.isDevelopment && isLocalTestBackend(url));
          container.dispose();
        }
      }
    }
  });
  testWidgets('production/direct widget never constructs a local login service', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      appEnvironmentProvider.overrideWithValue(const AppEnvironment.production()),
      localTestCenterRequestedProvider.overrideWithValue(true),
      localTestAccountServiceProvider.overrideWith((_) => throw StateError('must not read')),
    ], child: const MaterialApp(home: TestCenterScreen())));
    expect(find.text('Test Merkezi bu ortamda kapalı.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
  testWidgets('five roles render on a narrow screen without opening backend queries', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      localTestCenterEnabledProvider.overrideWithValue(true),
      currentProfileProvider.overrideWith((_) async => null),
    ], child: const MaterialApp(home: TestCenterScreen())));
    await tester.pump();
    expect(find.text('Antrenör olarak aç'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Muhasebeci olarak aç'), 160);
    expect(find.text('Muhasebeci olarak aç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
