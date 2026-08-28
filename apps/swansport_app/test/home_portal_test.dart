import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_workspace_screen.dart';
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
      'landing screen renders responsively across sizes and dark/light modes',
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

        expect(t.takeException(), isNull);

        await t.pumpWidget(const SizedBox());
      }
    }
  });

}
