import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  Future<void> pumpVault(
    WidgetTester tester,
    double width, {
    ThemeMode mode = ThemeMode.light,
  }) async {
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
          home: const DocumentVaultScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('real search field supports results, reset and no results',
      (tester) async {
    await pumpVault(tester, 600);
    final search = find.byKey(const Key('document-search-field'));
    await tester.enterText(search, 'Efe');
    await tester.pump();
    expect(find.text('Sağlık Raporu & EK-1.pdf'), findsOneWidget);
    await tester.enterText(search, 'not-found-value');
    await tester.pump();
    expect(find.byKey(const Key('document-no-results')), findsOneWidget);
    await tester.tap(find.byKey(const Key('document-search-reset')));
    await tester.pump();
    expect(
      find.byKey(const Key('document-card-document_consent_can')),
      findsOneWidget,
    );
  });

  testWidgets('vault is responsive and dark-mode safe', (tester) async {
    for (final width in [375.0, 600.0, 768.0, 1024.0, 1440.0]) {
      await pumpVault(tester, width);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    for (final width in [375.0, 1024.0]) {
      await pumpVault(tester, width, mode: ThemeMode.dark);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('typed list detail related navigation and back work',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed('/documents'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const Key('document-card-document_consent_can')));
    await tester.pumpAndSettle();
    expect(find.text('Veli Muvafakat Belgesi.pdf'), findsOneWidget);
    await tester
        .tap(find.byKey(const Key('related-document-document_medical_efe')));
    await tester.pumpAndSettle();
    expect(find.text('Sağlık Raporu & EK-1.pdf'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Veli Muvafakat Belgesi.pdf'), findsOneWidget);
  });
}
