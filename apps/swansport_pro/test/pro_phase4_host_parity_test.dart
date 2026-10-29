import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/features/dashboard/pro_dashboard_screen.dart';
import 'package:swansport_pro/features/operations/pro_tasks_screen.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets('platform workspace mounts shared Phase 4 panel in both hosts',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: true,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
            ),
          ),
          platformConfigProvider.overrideWith(
            (ref) async => const PlatformConfig.empty(),
          ),
          platformPlansProvider.overrideWith((ref) async => const []),
          platformAuditLogsProvider.overrideWith((ref) async => const []),
          launchWaitlistSummaryProvider.overrideWith(
            (ref) async => const LaunchWaitlistSummary(),
          ),
        ],
        child: const MaterialApp(
          home: Column(
            children: [
              Expanded(child: ProDashboardScreen()),
              Expanded(child: ProTasksScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SharedPlatformOperationsPanel), findsOneWidget);
    expect(find.byType(ProTasksScreen), findsOneWidget);
    expect(find.text('Bu çalışma alanı sonraki fazda açılacak'), findsNothing);
    expect(find.text('Bu çalışma alanı için operasyon görevi bulunmuyor.'),
        findsNothing);
  });
}
