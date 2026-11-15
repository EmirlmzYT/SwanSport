import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_app/app/navigation/app_routes.dart';
import 'package:swansport_app/app/navigation/legacy_navigation_bridge.dart';
import 'package:swansport_app/app/navigation/swan_back_navigation.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';
import 'package:swansport_app/app/app_navigator.dart';

void main() {
  test('history-less route parents are explicit and stable', () {
    expect(
      SwanBackNavigation.fallbackFor(AppRoutes.directMessage),
      AppRoutes.messages,
    );
    expect(
      SwanBackNavigation.fallbackFor(AppRoutes.partnerSearch),
      AppRoutes.explore,
    );
    expect(
      SwanBackNavigation.fallbackFor(AppRoutes.clubProfile),
      AppRoutes.explore,
    );
    expect(
      SwanBackNavigation.fallbackFor(AppRoutes.clubSettings),
      AppRoutes.profile,
    );
    expect(SwanBackNavigation.fallbackFor(AppRoutes.feed), isNull);
    expect(SwanBackNavigation.fallbackFor(AppRoutes.auth), isNull);
  });

  testWidgets('normal push pops once and preserves previous screen state',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextField(controller: controller),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/detay'),
                  child: const Text('Detay'),
                ),
              ],
            ),
          ),
        ),
        routes: {
          '/detay': (context) => Scaffold(
                appBar: swanModuleAppBar(context, title: 'Alt ekran'),
              ),
        },
      ),
    );
    await tester.enterText(find.byType(TextField), 'koru');
    await tester.tap(find.text('Detay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Geri dön'));
    await tester.pumpAndSettle();
    expect(find.text('koru'), findsOneWidget);
    expect(find.text('Alt ekran'), findsNothing);
  });

  testWidgets('Navigator 1 direct detail replaces with safe parent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: AppRoutes.directMessage),
            builder: (context) => Scaffold(
              appBar: swanModuleAppBar(context, title: 'Sohbet'),
            ),
          ),
        ],
        routes: {
          AppRoutes.messages: (_) => const Scaffold(body: Text('MESAJLAR')),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Geri dön'), findsOneWidget);
    await tester.tap(find.byTooltip('Geri dön'));
    await tester.pumpAndSettle();
    expect(find.text('MESAJLAR'), findsOneWidget);
    expect(find.text('Sohbet'), findsNothing);
  });

  testWidgets('GoRouter direct legacy target goes to verified safe parent',
      (tester) async {
    Route<dynamic>? legacyFactory(RouteSettings settings) {
      if (settings.name == AppRoutes.partnerSearch) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => Scaffold(
            appBar: swanModuleAppBar(context, title: 'Partner Bul'),
          ),
        );
      }
      return null;
    }

    final router = GoRouter(
      initialLocation: AppRoutes.partnerSearch,
      routes: [
        GoRoute(
          path: AppRoutes.explore,
          builder: (_, __) => const Scaffold(body: Text('KEŞFET')),
        ),
        GoRoute(
          path: AppRoutes.partnerSearch,
          builder: (_, __) => LegacyNavigationBridge(
            initialRoute: AppRoutes.partnerSearch,
            onGenerateRoute: legacyFactory,
          ),
        ),
      ],
    );
    swanGoRouter = router;
    addTearDown(() {
      swanGoRouter = null;
      router.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(
      SwanBackNavigation.routeOf(tester.element(find.text('Partner Bul'))),
      AppRoutes.partnerSearch,
    );
    expect(router.canPop(), isFalse);
    await tester.tap(find.byTooltip('Geri dön'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.explore);
    expect(find.text('KEŞFET'), findsOneWidget);
  });

  testWidgets('a vetoed draft pop is not mistaken for missing history',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: '/taslak'),
                builder: (context) => PopScope(
                  canPop: false,
                  child: Scaffold(
                    appBar: swanModuleAppBar(context, title: 'Taslak'),
                    body: const Text('KAYDEDİLMEDİ'),
                  ),
                ),
              ),
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('KAYDEDİLMEDİ'), findsOneWidget);
  });
}
