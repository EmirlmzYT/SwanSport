import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/routing/athlete_detail_route_args.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_detail_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Widget buildScreen({
    AthleteFull? athlete,
    bool returnNull = false,
    Object? error,
    ThemeMode themeMode = ThemeMode.light,
    String athleteId = 'athlete_can_yilmaz',
  }) {
    return ProviderScope(
      overrides: [
        athleteByIdProvider.overrideWith((ref, id) async {
          if (error != null) throw error;
          return id == athleteId && !returnNull ? athlete ?? _athlete : null;
        }),
      ],
      child: MaterialApp(
        theme: SwanTheme.light(),
        darkTheme: SwanTheme.dark(),
        themeMode: themeMode,
        home: AthleteDetailScreen(
          args: AthleteDetailRouteArgs(athleteId: SwanId(athleteId)),
        ),
      ),
    );
  }

  testWidgets('renders the production athlete profile content', (tester) async {
    await tester.pumpWidget(buildScreen());
    await pumpScreen(tester);

    expect(find.text('Can Yılmaz'), findsWidgets);
    expect(find.text('Aktif'), findsWidgets);
    expect(find.text('Forvet'), findsWidgets);
    expect(find.text('L-2026-01'), findsOneWidget);
    expect(find.text('Veli Davet Kodu Üret'), findsOneWidget);
  });

  testWidgets('renders the provider error state', (tester) async {
    await tester.pumpWidget(buildScreen(error: StateError('Fixture failed.')));
    await pumpScreen(tester);

    expect(find.textContaining('Fixture failed.'), findsOneWidget);
  });

  testWidgets('renders the not found state', (tester) async {
    await tester.pumpWidget(buildScreen(returnNull: true));
    await pumpScreen(tester);

    expect(find.text('Sporcu bulunamadı'), findsOneWidget);
    expect(find.text('Bu profile ulaşılamadı.'), findsOneWidget);
  });

  testWidgets('keeps the profile readable in dark mode', (tester) async {
    await tester.pumpWidget(buildScreen(themeMode: ThemeMode.dark));
    await pumpScreen(tester);

    expect(find.text('Can Yılmaz'), findsWidgets);
    expect(find.text('Lisans'), findsWidgets);
  });

  for (final width in <double>[375, 600, 768, 1024, 1440]) {
    testWidgets('renders without overflow at ${width.toInt()} px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildScreen());
      await pumpScreen(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Can Yılmaz'), findsWidgets);
    });
  }
}

final _athlete = AthleteFull(
  id: 'athlete_can_yilmaz',
  firstName: 'Can',
  lastName: 'Yılmaz',
  position: 'Forvet',
  birthDate: DateTime(2010, 6, 15),
  license: 'L-2026-01',
);
