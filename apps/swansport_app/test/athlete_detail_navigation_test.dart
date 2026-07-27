import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/routing/athlete_detail_route_args.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_detail_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  Future<void> pumpRouteAndDetail(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('route with valid athlete id opens athlete detail',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SwanSportApp(),
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    unawaited(
      navigator.pushNamed(
        '/athlete-detail',
        arguments: const AthleteDetailRouteArgs(
          athleteId: SwanId('athlete_can_yilmaz'),
        ),
      ),
    );

    await pumpRouteAndDetail(tester);

    expect(find.text('Can Yılmaz'), findsWidgets);
    expect(find.text('Yoklama'), findsOneWidget);
  });

  testWidgets('route with missing args opens safe invalid route state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SwanSportApp(),
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    unawaited(navigator.pushNamed('/athlete-detail'));

    await pumpRouteAndDetail(tester);

    expect(find.text('Sporcu bulunamadı'), findsOneWidget);
  });

  testWidgets('athlete detail back button returns to previous route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          routes: {
            '/': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/athlete-detail',
                      arguments: const AthleteDetailRouteArgs(
                        athleteId: SwanId('athlete_can_yilmaz'),
                      ),
                    ),
                    child: const Text('Open detail'),
                  ),
                ),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/athlete-detail') {
              final args = settings.arguments;

              return MaterialPageRoute<void>(
                builder: (context) => args is AthleteDetailRouteArgs
                    ? AthleteDetailScreen(args: args)
                    : const AthleteDetailScreen.invalidRoute(),
              );
            }

            return null;
          },
        ),
      ),
    );

    await tester.tap(find.text('Open detail'));
    await pumpRouteAndDetail(tester);
    await tester.tap(find.byTooltip('Geri dön'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Open detail'), findsOneWidget);
  });
}
