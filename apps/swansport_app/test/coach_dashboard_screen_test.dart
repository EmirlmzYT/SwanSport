import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/dashboard/presentation/screens/coach_dashboard_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  testWidgets('coach dashboard preserves primary coaching actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SwanTheme.light(),
        routes: {
          '/attendance': (_) => const Scaffold(body: Text('Attendance')),
          '/athletes': (_) => const Scaffold(body: Text('Athletes')),
        },
        home: const CoachDashboardScreen(),
      ),
    );

    expect(find.text('Kadıköy SK'), findsOneWidget);
    expect(find.text('Yoklama Al'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('%89'), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
  });
}
