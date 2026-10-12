import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  for (final url in [null, '', 'javascript:alert(1)', 'https://example.com/logo.png', 'https://example.com/logo.svg']) {
    testWidgets('invalid/missing/unavailable logo has safe bounded fallback: $url', (tester) async {
      await tester.pumpWidget(MaterialApp(home: SwanNetworkLogo(url: url, size: 24,
        fallback: const Icon(Icons.shield_moon_rounded))));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.shield_moon_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
