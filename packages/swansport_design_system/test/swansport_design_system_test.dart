import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  test('provides placeholder spacing tokens', () {
    expect(SwanSpacing.md, 16);
  });

  testWidgets('keeps a fixed-width long-label button within its bounds',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SwanButton.primary(
              width: 312,
              icon: Icons.admin_panel_settings_rounded,
              label: 'Platform yöneticisi izinlerini düzenle',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
