import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/calendar/presentation/screens/schedule_calendar_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  testWidgets('renders the production empty calendar state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsProvider.overrideWith((ref) async => const <EventRow>[]),
        ],
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const ScheduleCalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Yaklaşan Etkinlikler'), findsOneWidget);
    expect(find.text('Henüz etkinlik yok'), findsOneWidget);
    expect(find.text('Önce Kadro’dan bir kulüp oluştur.'), findsOneWidget);
  });

  testWidgets('keeps calendar navigation available in the empty state',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventsProvider.overrideWith((ref) async => const <EventRow>[]),
        ],
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const ScheduleCalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Yaklaşan Etkinlikler'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsWidgets);
  });
}
