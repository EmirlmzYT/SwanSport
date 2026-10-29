import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_theme.dart';
import 'package:swansport_pro/features/calendar/pro_calendar_screen.dart';

void main() {
  testWidgets(
      'renders authorized unified calendar data without mobile overflow',
      (tester) async {
    final today = calendarTurkeyTime(DateTime.now());
    final start = calendarDayStart(today).add(const Duration(hours: 10));
    final event = UnifiedCalendarEvent(
      id: 'club:test:event',
      title: 'Takım Antrenmanı',
      type: CalendarEventType.clubTraining,
      startsAt: start,
      status: 'scheduled',
      place: 'Test Sahası',
    );

    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unifiedCalendarMonthProvider.overrideWith(
            (ref, month) async => UnifiedCalendarData([event]),
          ),
        ],
        child: MaterialApp(
          theme: ProTheme.dark(),
          home: const ProCalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Takım Antrenmanı'), findsOneWidget);
    expect(find.text('Test Sahası'), findsOneWidget);
    expect(
        find.byKey(ValueKey('pro-calendar-day-${today.day}')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows partial-source warning without hiding available events',
      (tester) async {
    final today = calendarTurkeyTime(DateTime.now());
    final event = UnifiedCalendarEvent(
      id: 'official:test:event',
      title: 'Federasyon Programı',
      type: CalendarEventType.officialFederation,
      startsAt: calendarDayStart(today).add(const Duration(hours: 12)),
      status: 'published',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unifiedCalendarMonthProvider.overrideWith(
            (ref, month) async => UnifiedCalendarData(
              [event],
              clubUnavailable: true,
            ),
          ),
        ],
        child: MaterialApp(
          theme: ProTheme.dark(),
          home: const ProCalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Kulüp takvim kaynağı'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Federasyon Programı'), findsOneWidget);
  });
}
