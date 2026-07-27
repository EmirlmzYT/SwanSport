import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_workspace_screen.dart';
import 'package:swansport_app/features/home/presentation/screens/main_hub_dashboard_screen.dart';
import 'package:swansport_app/features/home/presentation/screens/public_landing_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  testWidgets('public landing screen renders hero and enterprise modules grid',
      (t) async {
    t.view.physicalSize = const Size(1024, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(
      MaterialApp(
        theme: SwanTheme.light(),
        home: const PublicLandingScreen(),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('landing-hero')), findsOneWidget);
    expect(find.byKey(const Key('landing-modules-grid')), findsOneWidget);
  });

  testWidgets(
      'main hub dashboard renders live KPIs and 15-module launcher grid',
      (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          darkTheme: SwanTheme.dark(),
          home: const MainHubDashboardScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('hub-hero-kpis')), findsOneWidget);
    expect(find.byKey(const Key('hub-launcher-section')), findsOneWidget);
    expect(find.byKey(const Key('launch-athletes')), findsOneWidget);
    expect(find.byKey(const Key('launch-medical-center')), findsOneWidget);
    expect(
      find.byKey(const Key('launch-financial-management')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('launch-performance-analytics')),
      findsOneWidget,
    );
  });

  testWidgets(
      'landing and hub screens render responsively across sizes and dark/light modes',
      (t) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final w in mode == ThemeMode.light
          ? [375.0, 600.0, 768.0, 1024.0, 1440.0]
          : [375.0, 1024.0]) {
        t.view.physicalSize = Size(w, 1000);
        t.view.devicePixelRatio = 1;

        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: SwanTheme.light(),
              darkTheme: SwanTheme.dark(),
              themeMode: mode,
              home: const PublicLandingScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);

        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: SwanTheme.light(),
              darkTheme: SwanTheme.dark(),
              themeMode: mode,
              home: const MainHubDashboardScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);

        await t.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('navigation from hub dashboard launcher items works', (t) async {
    t.view.physicalSize = const Size(1024, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();

    final nav = t.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/hub'));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('launch-athletes')), findsOneWidget);

    await t.tap(find.byKey(const Key('launch-athletes')));
    await t.pumpAndSettle();

    expect(find.byType(AthleteWorkspaceScreen), findsOneWidget);
  });
}
