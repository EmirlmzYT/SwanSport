import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/settings/presentation/screens/club_settings_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  Future<void> pump(WidgetTester tester, double width, ThemeMode mode) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          darkTheme: SwanTheme.dark(),
          themeMode: mode,
          home: const ClubSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('settings account shortcuts render', (tester) async {
    await pump(tester, 600, ThemeMode.light);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Profilim'), findsOneWidget);
    expect(find.text('Veli bağlantısı'), findsOneWidget);
    expect(find.text('Gizlilik ve engellenenler'), findsOneWidget);
  });

  testWidgets('responsive and dark layouts do not overflow', (tester) async {
    for (final width in [375.0, 600.0, 768.0, 1024.0, 1440.0]) {
      await pump(tester, width, ThemeMode.light);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    for (final width in [375.0, 1024.0]) {
      await pump(tester, width, ThemeMode.dark);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('platform management route guards non-admin users',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/onay-paneli'));
    await tester.pumpAndSettle();
    expect(find.text('Yetkin yok'), findsOneWidget);
  });
}
