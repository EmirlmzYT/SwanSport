import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/calendar/presentation/screens/schedule_calendar_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  testWidgets('renders fixture analytics, recurrence and RSVP summary',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const ScheduleCalendarScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('WORKLOAD & FACILITY ANALYTICS'), findsOneWidget);
    expect(find.textContaining('Her hafta Çarşamba'), findsOneWidget);
    expect(find.textContaining('Ön RSVP:'), findsWidgets);
  });

  testWidgets('view switcher changes selected calendar view', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const ScheduleCalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Tesis Gridi'));
    await tester.pump();

    expect(find.text('Caferağa Spor Salonu • Salon A'), findsWidgets);
  });
}
