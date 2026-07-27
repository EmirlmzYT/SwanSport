import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/routing/athlete_detail_route_args.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_detail_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  Future<void> pumpAthleteDetail(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders loaded athlete detail from fixture data',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const AthleteDetailScreen(
            args: AthleteDetailRouteArgs(
              athleteId: SwanId('athlete_can_yilmaz'),
            ),
          ),
        ),
      ),
    );

    await pumpAthleteDetail(tester);

    expect(find.text('Can Yılmaz'), findsWidgets);
    expect(find.text('%94'), findsOneWidget);
    expect(find.text('Sağlık Raporu Geçerli'), findsOneWidget);
    expect(find.text('Aktivite'), findsOneWidget);
  });

  testWidgets('renders invalid route state without athlete id', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const AthleteDetailScreen.invalidRoute(),
        ),
      ),
    );

    expect(find.text('Sporcu bulunamadı'), findsOneWidget);
    expect(find.textContaining('sporcu kimliği'), findsOneWidget);
  });

  testWidgets('renders not found state for unknown athlete id', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const AthleteDetailScreen(
            args: AthleteDetailRouteArgs(
              athleteId: SwanId('missing_athlete'),
            ),
          ),
        ),
      ),
    );

    await pumpAthleteDetail(tester);

    expect(find.text('Sporcu bulunamadı'), findsOneWidget);
    expect(find.text('Athlete was not found.'), findsOneWidget);
  });

  testWidgets('renders in dark mode without losing core content',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          darkTheme: SwanTheme.dark(),
          themeMode: ThemeMode.dark,
          home: const AthleteDetailScreen(
            args: AthleteDetailRouteArgs(
              athleteId: SwanId('athlete_can_yilmaz'),
            ),
          ),
        ),
      ),
    );

    await pumpAthleteDetail(tester);

    expect(find.text('Can Yılmaz'), findsWidgets);
    expect(find.text('Evraklar'), findsOneWidget);
  });
}
