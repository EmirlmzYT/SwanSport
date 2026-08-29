import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/routing/athlete_detail_route_args.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_detail_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  Future<void> pumpAthleteDetail(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  ProviderScope scope(Widget child) => ProviderScope(
        overrides: [
          athleteByIdProvider.overrideWith(
              (ref, id) async => id == 'athlete_can_yilmaz' ? _athlete : null),
        ],
        child: child,
      );

  testWidgets('renders loaded athlete detail from fixture data',
      (tester) async {
    await tester.pumpWidget(
      scope(
        MaterialApp(
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
    expect(find.text('Lisans'), findsWidgets);
    expect(find.text('Forvet'), findsWidgets);
    expect(find.text('Veli Davet Kodu Üret'), findsOneWidget);
  });

  testWidgets('renders invalid route state without athlete id', (tester) async {
    await tester.pumpWidget(
      scope(
        MaterialApp(
          theme: SwanTheme.light(),
          home: const AthleteDetailScreen.invalidRoute(),
        ),
      ),
    );

    expect(find.text('Sporcu bulunamadı'), findsOneWidget);
    expect(find.text('Bu profile ulaşılamadı.'), findsOneWidget);
  });

  testWidgets('renders not found state for unknown athlete id', (tester) async {
    await tester.pumpWidget(
      scope(
        MaterialApp(
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
    expect(find.text('Bu profile ulaşılamadı.'), findsOneWidget);
  });

  testWidgets('renders in dark mode without losing core content',
      (tester) async {
    await tester.pumpWidget(
      scope(
        MaterialApp(
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
    expect(find.text('Lisans'), findsWidgets);
  });
}

final _athlete = AthleteFull(
  id: 'athlete_can_yilmaz',
  firstName: 'Can',
  lastName: 'Yılmaz',
  position: 'Forvet',
  birthDate: DateTime(2010, 6, 15),
  license: 'L-2026-01',
);
