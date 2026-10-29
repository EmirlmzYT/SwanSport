import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_app/app/navigation/app_router.dart';
import 'package:swansport_app/app/navigation/legacy_navigation_bridge.dart';

void main() {
  late GoRouter router;

  tearDown(() => router.dispose());

  testWidgets('legacy pushNamed works inside a stateful shell branch',
      (tester) async {
    Route<dynamic>? legacyFactory(RouteSettings settings) {
      if (settings.name == '/detay') {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            appBar: AppBar(),
            body: const Text('Legacy detay'),
          ),
        );
      }
      return null;
    }

    Widget branch(String location, String label) => LegacyNavigationBridge(
          initialRoute: location,
          onGenerateRoute: legacyBranchRouteFactory(
            rootLocation: location,
            rootBuilder: (_) => Scaffold(
              body: Column(
                children: <Widget>[
                  Text(label),
                  TextField(key: Key('field-$label')),
                  Builder(
                    builder: (context) => FilledButton(
                      onPressed: () => Navigator.pushNamed(context, '/detay'),
                      child: const Text('Detayı aç'),
                    ),
                  ),
                ],
              ),
            ),
            legacyFactory: legacyFactory,
          ),
        );

    router = buildSwanRouter(
      feedBuilder: (_, __) => branch('/akis', 'Akış'),
      exploreBuilder: (_, __) => branch('/kesfet', 'Keşfet'),
      messagesBuilder: (_, __) => branch('/mesajlar', 'Mesajlar'),
      profileBuilder: (_, __) => branch('/profil', 'Profil'),
      shellBuilder: (_, __, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: Row(
          children: <Widget>[
            TextButton(
              onPressed: () => shell.goBranch(0),
              child: const Text('Akış sekmesi'),
            ),
            TextButton(
              onPressed: () => shell.goBranch(1),
              child: const Text('Keşfet sekmesi'),
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byKey(const Key('field-Akış')), 'sakla');
    await tester.tap(find.text('Detayı aç'));
    await tester.pumpAndSettle();
    expect(find.text('Legacy detay'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('sakla'), findsOneWidget);

    await tester.tap(find.text('Keşfet sekmesi'));
    await tester.pumpAndSettle();
    expect(find.text('Keşfet'), findsOneWidget);

    await tester.tap(find.text('Akış sekmesi'));
    await tester.pumpAndSettle();
    expect(find.text('sakla'), findsOneWidget);
  });
}
