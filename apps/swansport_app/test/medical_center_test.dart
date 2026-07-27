import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/medical_center/domain/medical_center.dart';
import 'package:swansport_app/features/medical_center/presentation/medical_center_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  test(
      'medical domain filters, permissions, and status updates work deterministically',
      () {
    final repo = FixtureMedicalRepository();
    final profile = repo.profiles.first;
    expect(profile.athleteName, 'Arda Yılmaz');
    expect(const MedicalFilter(query: 'Arda').matches(profile), isTrue);
    expect(const MedicalFilter(query: 'Basketbol').matches(profile), isFalse);

    // Doctor notes permission check
    expect(
      permissionsForMedicalRole(MedicalRole.doctor).canViewDoctorNotes,
      isTrue,
    );
    expect(
      permissionsForMedicalRole(MedicalRole.coach).canViewDoctorNotes,
      isFalse,
    );
    expect(
      permissionsForMedicalRole(MedicalRole.parent).canViewDoctorNotes,
      isFalse,
    );

    // Eligibility update check
    final updated = repo.updateEligibility(
      profile.id,
      MedicalEligibilityStatus.temporarilyRestricted,
    );
    expect(updated.eligibility, MedicalEligibilityStatus.temporarilyRestricted);

    // Metrics check
    final metrics = repo.metrics;
    expect(metrics.totalAthletes, 3);
    expect(metrics.rehabCases, 1);
    expect(repo.appointments.single.status, MedicalAppointmentStatus.scheduled);
    expect(
      repo.clearances.single.status,
      MedicalClearanceStatus.expired,
    );
    expect(repo.audit, hasLength(1));
  });

  testWidgets(
      'medical center renders responsively across sizes and dark/light modes',
      (t) async {
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
              home: const MedicalCenterScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets(
      'medical center search, detail navigation and doctor notes privacy work',
      (t) async {
    t.view.physicalSize = const Size(900, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();

    final nav = t.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/medical-center'));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('medical-command-center')), findsOneWidget);
    expect(find.byKey(const Key('medical-appointments')), findsOneWidget);
    expect(find.byKey(const Key('medical-clearances')), findsOneWidget);
    expect(find.byKey(const Key('medical-audit')), findsOneWidget);

    await t.enterText(find.byKey(const Key('medical-search')), 'Arda');
    await t.pump();

    await t.tap(find.byKey(const Key('medical-athlete_1')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('medical-detail-name')), findsOneWidget);
    expect(find.byKey(const Key('confidential-doctor-notes')), findsOneWidget);
  });
}
