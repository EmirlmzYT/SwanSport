import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/calendar/presentation/screens/schedule_calendar_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  for (final width in [375.0, 600.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('renders without overflow at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsProvider.overrideWith((ref) async => const <EventRow>[]),
          ],
          child: MaterialApp(
            theme: SwanTheme.light(),
            darkTheme: SwanTheme.dark(),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.2)),
              child: ScheduleCalendarScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [375.0, 1024.0]) {
    testWidgets(
        'renders the calendar empty state in dark mode at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventsProvider.overrideWith((ref) async => const <EventRow>[]),
          ],
          child: MaterialApp(
            theme: SwanTheme.light(),
            darkTheme: SwanTheme.dark(),
            themeMode: ThemeMode.dark,
            home: const ScheduleCalendarScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Yaklaşan Etkinlikler'), findsOneWidget);
      expect(find.text('Henüz etkinlik yok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
