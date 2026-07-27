import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/configuration/presentation/configuration_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  Future<void> pump(WidgetTester t, double width, ThemeMode mode) async {
    t.view.physicalSize = Size(width, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          darkTheme: SwanTheme.dark(),
          themeMode: mode,
          home: const ConfigurationScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('instant search filters and no results render', (t) async {
    await pump(t, 600, ThemeMode.light);
    await t.enterText(find.byKey(const Key('configuration-search')), 'KVKK');
    await t.pump();
    expect(
      find.byKey(const Key('configuration-setting-legal')),
      findsOneWidget,
    );
    await t.enterText(find.byKey(const Key('configuration-search')), 'none');
    await t.pump();
    expect(find.byKey(const Key('configuration-no-results')), findsOneWidget);
  });
  testWidgets('responsive dark and typed module navigation work', (t) async {
    for (final w in [375.0, 600.0, 768.0, 1024.0, 1440.0]) {
      await pump(t, w, ThemeMode.light);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    }
    for (final w in [375.0, 1024.0]) {
      await pump(t, w, ThemeMode.dark);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    }
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/configuration'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('configuration-setting-club_name')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('configuration-value')), findsOneWidget);
  });
}
