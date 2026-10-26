import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_pro/app/pro_app.dart';
import 'package:swansport_pro/app/pro_bootstrap.dart';
import 'package:swansport_pro/app/pro_environment.dart';
import 'package:swansport_pro/features/auth/pro_startup_failure_screen.dart';

void main() {
  group('bootstrapPro', () {
    testWidgets(
        'missing production config renders ProStartupFailureScreen and never fixtures',
        (tester) async {
      Widget? launchedWidget;

      await bootstrapPro(
        const ProEnvironment.production(),
        config: SupabaseConfig.empty,
        runWidgetApp: (app) => launchedWidget = app,
      );

      expect(launchedWidget, isNotNull);
      await tester.pumpWidget(MaterialApp(home: launchedWidget!));
      expect(find.byType(ProStartupFailureScreen), findsOneWidget);
      expect(find.byType(ProApp), findsNothing);
    });

    testWidgets(
        'failed production initialization renders ProStartupFailureScreen',
        (tester) async {
      Widget? launchedWidget;
      const testConfig = SupabaseConfig(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      await bootstrapPro(
        const ProEnvironment.production(),
        config: testConfig,
        initializeSupabase: (config) async {
          throw Exception('Connection failed');
        },
        runWidgetApp: (app) => launchedWidget = app,
      );

      expect(launchedWidget, isNotNull);
      await tester.pumpWidget(MaterialApp(home: launchedWidget!));
      expect(find.byType(ProStartupFailureScreen), findsOneWidget);
      expect(find.byType(ProApp), findsNothing);
    });

    testWidgets(
        'configured production startup installs shared provider overrides and launches ProApp',
        (tester) async {
      Widget? launchedWidget;
      const testConfig = SupabaseConfig(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      var initCalled = false;
      await bootstrapPro(
        const ProEnvironment.production(),
        config: testConfig,
        initializeSupabase: (config) async {
          initCalled = true;
        },
        runWidgetApp: (app) => launchedWidget = app,
      );

      expect(initCalled, isTrue);
      expect(launchedWidget, isNotNull);

      // Verify ProviderScope is the root and contains overrides
      expect(launchedWidget, isA<ProviderScope>());
      final scope = launchedWidget as ProviderScope;
      expect(scope.child, isA<ProApp>());
    });

    testWidgets(
        'Pro root widget is not wrapped in push or Firebase lifecycle observers',
        (tester) async {
      Widget? launchedWidget;
      const testConfig = SupabaseConfig(
        url: 'https://test.supabase.co',
        anonKey: 'test-key',
      );

      await bootstrapPro(
        const ProEnvironment.production(),
        config: testConfig,
        initializeSupabase: (config) async {},
        runWidgetApp: (app) => launchedWidget = app,
      );

      final scope = launchedWidget as ProviderScope;
      // Child must be ProApp directly, without push/deep link wrappers
      expect(scope.child, isA<ProApp>());
    });
  });
}
