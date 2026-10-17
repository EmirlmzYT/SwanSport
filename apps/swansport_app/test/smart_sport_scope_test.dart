import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/training/presentation/widgets/smart_sport_scope_bar.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  Future<void> render(WidgetTester tester, List<String> codes) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      activeClubProvider.overrideWith((ref) async => null),
      sportContextOptionsProvider.overrideWithValue(AsyncData(catalogSportsFor(codes))),
    ], child: const MaterialApp(home: Scaffold(body: SmartSportScopeBar()))));
    await tester.pumpAndSettle();
  }
  testWidgets('single sport is a badge without another selection step', (tester) async {
    await render(tester, ['yuzme']);
    expect(find.byType(Chip), findsOneWidget);
    expect(find.text('Yüzme'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
  testWidgets('multi-sport pills update the shared effective filter', (tester) async {
    await render(tester, ['yuzme', 'okculuk']);
    await tester.tap(find.text('Okçuluk'));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(SmartSportScopeBar)));
    expect(container.read(effectiveSportContextProvider), 'okculuk');
    await tester.tap(find.text('Tümü'));
    await tester.pump();
    expect(container.read(effectiveSportContextProvider), isNull);
  });
  testWidgets('five branches expose searchable full catalog', (tester) async {
    await render(tester, ['yuzme', 'okculuk', 'futbol', 'basketbol', 'tenis']);
    await tester.tap(find.text('Tüm Branşlar (60)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Satranç');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Satranç'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Satranç'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(SmartSportScopeBar)));
    expect(container.read(effectiveSportContextProvider), 'satranc');
  });
}
