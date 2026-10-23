import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/navigation/shell_navigation_scope.dart';
import 'package:swansport_app/app/widgets/swan_bottom_nav.dart';

void main() {
  testWidgets('embedded bottom navigation is hidden inside shell branches',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SwanShellNavigationScope(
            child: Scaffold(bottomNavigationBar: SwanBottomNav()),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('swan-bottom-nav-surface')), findsNothing);
  });
}
