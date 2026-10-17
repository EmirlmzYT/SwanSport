import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/app/design/swan_chrome.dart';
import 'package:swansport_app/app/widgets/scroll_chrome.dart';
import 'package:swansport_app/app/widgets/swan_bottom_nav.dart';

void main() {
  test('hysteresis ignores jitter and reverses without scrolling back to the top', () {
    final chrome = ScrollChromeController();
    addTearDown(chrome.dispose);
    chrome.travel(10); expect(chrome.compact, isFalse);
    chrome.travel(-2); chrome.travel(10); expect(chrome.compact, isFalse);
    chrome.travel(SwanChrome.hideTravel); expect(chrome.compact, isTrue);
    chrome.travel(-5); expect(chrome.compact, isTrue);
    chrome.travel(-SwanChrome.revealTravel); expect(chrome.compact, isFalse);
    chrome.travel(double.nan); expect(chrome.compact, isFalse);
    chrome.travel(SwanChrome.hideTravel); chrome.reset(); expect(chrome.compact, isFalse);
  });
  testWidgets('route-local compact nav keeps all destinations and 48dp touch height', (tester) async {
    final chrome = ScrollChromeController();
    addTearDown(chrome.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentProfileProvider.overrideWith((ref) async => null),
      swanAccessProvider.overrideWithValue(SwanAccess.none),
    ], child: MaterialApp(home: ScrollChromeScope(controller: chrome,
      child: const Scaffold(extendBody: true, bottomNavigationBar: SwanBottomNav())))));
    await tester.pumpAndSettle();
    final surface = find.byKey(const Key('swan-bottom-nav-surface'));
    expect(tester.getSize(surface).height, SwanChrome.expandedHeight);
    chrome.travel(SwanChrome.hideTravel);
    await tester.pumpAndSettle();
    expect(tester.getSize(surface).height, SwanChrome.compactHeight);
    for (final label in ['Ana Sayfa', 'Keşfet', 'Mesajlar', 'Profil']) {
      expect(find.byTooltip(label), findsOneWidget);
    }
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    chrome.travel(-SwanChrome.revealTravel);
    await tester.pumpAndSettle();
    expect(tester.getSize(surface).height, SwanChrome.expandedHeight);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('horizontal and ballistic notifications do not change compact state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    final chrome = ScrollChromeController(); addTearDown(chrome.dispose);
    final horizontal = FixedScrollMetrics(minScrollExtent: 0, maxScrollExtent: 500,
      pixels: 100, viewportDimension: 300, axisDirection: AxisDirection.right, devicePixelRatio: 1);
    chrome.onScroll(ScrollUpdateNotification(metrics: horizontal, context: context,
      scrollDelta: 100, dragDetails: DragUpdateDetails(globalPosition: Offset.zero)));
    expect(chrome.compact, isFalse);
    final vertical = FixedScrollMetrics(minScrollExtent: 0, maxScrollExtent: 500,
      pixels: 100, viewportDimension: 300, axisDirection: AxisDirection.down, devicePixelRatio: 1);
    chrome.onScroll(ScrollUpdateNotification(metrics: vertical, context: context, scrollDelta: 100));
    expect(chrome.compact, isFalse);
  });
}
