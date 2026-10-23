import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/navigation/legacy_route_registry.dart';

void main() {
  testWidgets('branch factory resolves static and dynamic legacy routes',
      (tester) async {
    final routes = <String, WidgetBuilder>{
      '/statik': (_) => const Text('Statik'),
    };
    Route<dynamic>? dynamicFactory(RouteSettings settings) {
      if (settings.name != '/dinamik') return null;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Text('Dinamik'),
      );
    }

    final factory = LegacyRouteRegistry.branchFactory(
      routes: routes,
      onGenerateRoute: dynamicFactory,
    );

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/statik',
        onGenerateRoute: factory,
      ),
    );
    expect(find.text('Statik'), findsOneWidget);

    Navigator.of(tester.element(find.text('Statik'))).pushNamed('/dinamik');
    await tester.pumpAndSettle();
    expect(find.text('Dinamik'), findsOneWidget);
  });
}
