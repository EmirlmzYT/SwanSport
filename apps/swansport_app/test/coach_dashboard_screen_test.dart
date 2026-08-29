import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/dashboard/presentation/screens/coach_dashboard_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  testWidgets('coach dashboard preserves primary coaching actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          routes: {
            '/attendance': (_) => const Scaffold(body: Text('Attendance')),
            '/athletes': (_) => const Scaffold(body: Text('Athletes')),
          },
          home: const CoachDashboardScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('SwanSport'), findsOneWidget);
    expect(find.text('İyi çalışmalar,'), findsOneWidget);
    expect(find.text('Aktif sporcu'), findsOneWidget);
    expect(find.text('Etkinlik'), findsOneWidget);
  });
}
