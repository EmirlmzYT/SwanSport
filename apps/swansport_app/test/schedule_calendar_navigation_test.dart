import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/calendar/application/schedule_calendar_controller.dart';
import 'package:swansport_app/features/calendar/data/fixtures/schedule_calendar_fixture_data_source.dart';
import 'package:swansport_app/features/calendar/data/repositories/fixture_schedule_calendar_repository.dart';
import 'package:swansport_app/features/calendar/domain/models/calendar_workspace.dart';
import 'package:swansport_app/features/calendar/presentation/screens/schedule_calendar_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  testWidgets('attendance CTA navigates to the attendance route',
      (tester) async {
    tester.view.physicalSize = const Size(375, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_calendarTestApp());
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Yoklama Al'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance destination'), findsOneWidget);
  });

  testWidgets('athlete role does not expose attendance CTA or navigate',
      (tester) async {
    await tester.pumpWidget(
      _calendarTestApp(role: CalendarRole.athlete),
    );
    await tester.pump();

    expect(find.widgetWithText(ElevatedButton, 'Yoklama Al'), findsNothing);
    expect(find.text('Attendance destination'), findsNothing);
  });
}

Widget _calendarTestApp({CalendarRole role = CalendarRole.headCoach}) {
  return ProviderScope(
    overrides: [
      scheduleCalendarControllerProvider.overrideWith(
        (ref) => ScheduleCalendarController(
          repository: const FixtureScheduleCalendarRepository(
            FixtureScheduleCalendarDataSource(),
          ),
          role: role,
        ),
      ),
    ],
    child: MaterialApp(
      theme: SwanTheme.light(),
      routes: {
        '/attendance': (_) =>
            const Scaffold(body: Center(child: Text('Attendance destination'))),
      },
      home: const ScheduleCalendarScreen(),
    ),
  );
}
