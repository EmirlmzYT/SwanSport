import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/platform_scroll_behavior.dart';

void main() {
  testWidgets('Android uses native clamping scroll physics', (tester) async {
    late ScrollPhysics physics;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Builder(
          builder: (context) {
            physics = const SwanScrollBehavior().getScrollPhysics(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(physics, isA<ClampingScrollPhysics>());
    expect(physics, isNot(isA<BouncingScrollPhysics>()));
  });

  testWidgets('iOS keeps native bouncing scroll physics', (tester) async {
    late ScrollPhysics physics;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) {
            physics = const SwanScrollBehavior().getScrollPhysics(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(physics, isA<BouncingScrollPhysics>());
  });
}
