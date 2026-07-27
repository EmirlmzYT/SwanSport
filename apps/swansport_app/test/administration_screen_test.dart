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

  testWidgets('directory search and view-as work', (tester) async {
    await pump(tester, 600, ThemeMode.light);
    await tester.enterText(find.byKey(const Key('admin-search')), 'Selin');
    await tester.pump();
    expect(find.text('Selin Yılmaz'), findsOneWidget);
    await tester.tap(find.byTooltip('Salt okunur görüntüle'));
    await tester.pump();
    expect(find.textContaining('Salt Okunur'), findsOneWidget);
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

  testWidgets('typed directory detail navigation works', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin-user-user_ahmet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-user-detail-name')), findsOneWidget);
  });
}
