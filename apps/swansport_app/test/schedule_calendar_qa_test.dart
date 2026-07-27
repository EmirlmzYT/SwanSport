import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/calendar/presentation/screens/schedule_calendar_screen.dart';
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
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [375.0, 1024.0]) {
    testWidgets('renders loaded Screen 6 in dark mode at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: SwanTheme.light(),
            darkTheme: SwanTheme.dark(),
            themeMode: ThemeMode.dark,
            home: const ScheduleCalendarScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('WORKLOAD & FACILITY ANALYTICS'), findsOneWidget);
      expect(find.text('Tesis Gridi'), findsOneWidget);
      expect(find.textContaining('Her hafta Çarşamba'), findsOneWidget);
      expect(find.textContaining('Ön RSVP:'), findsWidgets);
      expect(find.textContaining('Kısa toparlanma penceresi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
