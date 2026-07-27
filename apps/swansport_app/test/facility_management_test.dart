import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/facilities/application/facility_controller.dart';
import 'package:swansport_app/features/facilities/domain/facility_management.dart';
import 'package:swansport_app/features/facilities/presentation/facility_management_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  test('health filters permissions and hard conflicts are deterministic', () {
    final repo = FixtureFacilityRepository(), f = repo.facilities.first;
    expect(f.health, 100);
    expect(const FacilityFilter(query: 'Salon A').matches(f), isTrue);
    expect(permissionsForFacility(FacilityRole.parent).canEdit, isFalse);
    final overlap = FacilityReservation(
      id: const SwanId('new'),
      zoneId: const SwanId('facility_caferaga_a'),
      title: 'Çakışan',
      start: DateTime(2026, 7, 24, 19),
      end: DateTime(2026, 7, 24, 21),
      attendees: 12,
      status: ReservationStatus.pending,
    );
    expect(repo.conflict(f, overlap)!.message, contains('çakışması'));
    final maintenance = overlap.copyWithForTest(
      zoneId: const SwanId('facility_caferaga_b'),
      start: DateTime(2026, 7, 24, 10),
      end: DateTime(2026, 7, 24, 11),
    );
    expect(repo.conflict(f, maintenance)!.message, contains('bakımda'));
  });
  testWidgets('search responsive dark and typed detail work', (t) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final w in mode == ThemeMode.light
          ? [375.0, 600.0, 768.0, 1024.0, 1440.0]
          : [375.0, 1024.0]) {
        t.view.physicalSize = Size(w, 1000);
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: SwanTheme.light(),
              darkTheme: SwanTheme.dark(),
              themeMode: mode,
              home: const FacilityManagementScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    }
    t.view.physicalSize = const Size(800, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/facilities'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('facility-search')), 'Caferağa');
    await t.pump();
    await t.tap(find.byKey(const Key('facility-facility_caferaga')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('facility-detail-name')), findsOneWidget);
  });
}

extension on FacilityReservation {
  FacilityReservation copyWithForTest({
    required SwanId zoneId,
    required DateTime start,
    required DateTime end,
  }) =>
      FacilityReservation(
        id: id,
        zoneId: zoneId,
        title: title,
        start: start,
        end: end,
        attendees: attendees,
        status: status,
      );
}
