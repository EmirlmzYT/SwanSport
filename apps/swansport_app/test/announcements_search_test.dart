import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/announcements/presentation/screens/announcements_screen.dart';

void main() {
  testWidgets('searches through the real communication search field',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AnnouncementsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('communication-search-field'));
    expect(field, findsOneWidget);
    await tester.enterText(field, 'definitely-no-result');
    await tester.pumpAndSettle();

    expect(find.textContaining('bulunamad'), findsOneWidget);
    await tester.tap(find.byKey(const Key('communication-search-clear')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, isEmpty);
  });
}
