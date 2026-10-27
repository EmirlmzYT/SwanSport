import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  group('SharedFacilityReservationsScreen Gate & Authorization Tests', () {
    testWidgets(
        'gate closed (no facilityConflicts flag) -> fail-closed empty state',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({}), // facilityConflicts missing
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'coach',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityReservationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rezervasyon Yetkisi Yok'), findsOneWidget);
      expect(
        find.byKey(const Key('facility-reservations-dropdown')),
        findsNothing,
      );
    });

    testWidgets('non-staff member -> fail-closed empty state', (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'athlete',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.facilityConflicts}),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'athlete',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityReservationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rezervasyon Yetkisi Yok'), findsOneWidget);
      expect(
        find.byKey(const Key('facility-reservations-dropdown')),
        findsNothing,
      );
    });
  });

  group('SharedFacilityReservationsScreen Verification & Privacy Tests', () {
    const validFacId = '11111111-1111-1111-1111-111111111111';

    testWidgets(
        'foreign club facility or invalid UUID produces "Doğrulanamıyor" and never queries reservations',
        (tester) async {
      var queryExecuted = false;
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.facilityConflicts}),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'coach',
            ),
          ),
          facilitiesProvider.overrideWith(
            (ref) async => const [
              FacilityRow(
                id: validFacId,
                occupancy: 0,
                name: 'Anadolu Salonu',
                status: 'Müsait',
              ),
            ],
          ),
          narrowFacilityReservationsProvider(
            '99999999-9999-9999-9999-999999999999',
          ).overrideWith((ref) {
            queryExecuted = true;
            return [];
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityReservationsScreen(
            initialFacilityId:
                '99999999-9999-9999-9999-999999999999', // Foreign facility
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Doğrulanamıyor'), findsOneWidget);
      expect(find.text('Kayıtlı rezervasyon yok'), findsNothing);
      expect(queryExecuted, isFalse);
    });

    testWidgets(
        'verified facility with reservations renders titles, kind, status and NEVER leaks PII phone or private name',
        (tester) async {
      final start = DateTime.now().add(const Duration(hours: 2));
      final end = start.add(const Duration(hours: 1));

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.facilityConflicts}),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'coach',
            ),
          ),
          facilitiesProvider.overrideWith(
            (ref) async => const [
              FacilityRow(
                id: validFacId,
                occupancy: 0,
                name: 'Anadolu Salonu',
                status: 'Müsait',
              ),
            ],
          ),
          narrowFacilityReservationsProvider(validFacId).overrideWith(
            (ref) async => [
              FacilityReservation(
                id: 'res-1',
                clubId: 'club-1',
                facilityId: validFacId,
                title: 'Özel Antrenman Seansı',
                kind: 'rental',
                startsAt: start,
                endsAt: end,
                status: 'confirmed',
                fee: 0,
                // Even if somehow dummy model had PII, UI must not render them
                reservedByName: 'Gizli Kisi Adi',
                reservedByPhone: '05559998877',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityReservationsScreen(
            initialFacilityId: validFacId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Özel Antrenman Seansı'), findsOneWidget);
      expect(find.text('Onaylı'), findsOneWidget);
      expect(find.text('Kiralama'), findsOneWidget);

      // PII leak verification: Phone and private name MUST NOT be present
      expect(find.text('05559998877'), findsNothing);
      expect(find.text('Gizli Kisi Adi'), findsNothing);
      expect(find.textContaining('0555'), findsNothing);
    });

    testWidgets(
        'verified facility with empty list displays "Kayıtlı rezervasyon yok" distinct from error or unverified',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.facilityConflicts}),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'coach',
            ),
          ),
          facilitiesProvider.overrideWith(
            (ref) async => const [
              FacilityRow(
                id: validFacId,
                occupancy: 0,
                name: 'Anadolu Salonu',
                status: 'Müsait',
              ),
            ],
          ),
          narrowFacilityReservationsProvider(validFacId).overrideWith(
            (ref) async => const [],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityReservationsScreen(
            initialFacilityId: validFacId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kayıtlı rezervasyon yok'), findsOneWidget);
      expect(find.text('Doğrulanamıyor'), findsNothing);
    });

    testWidgets(
        'facility change switches displayed reservations without state leakage',
        (tester) async {
      const fac2Id = '22222222-2222-2222-2222-222222222222';
      final now = DateTime.now();

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.facilityConflicts}),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'coach',
            ),
          ),
          facilitiesProvider.overrideWith(
            (ref) async => const [
              FacilityRow(
                id: validFacId,
                occupancy: 0,
                name: 'Salon 1',
                status: 'Müsait',
              ),
              FacilityRow(
                id: fac2Id,
                occupancy: 0,
                name: 'Salon 2',
                status: 'Müsait',
              ),
            ],
          ),
          narrowFacilityReservationsProvider(validFacId).overrideWith(
            (ref) async => [
              FacilityReservation(
                id: 'res-fac1',
                clubId: 'club-1',
                facilityId: validFacId,
                title: 'Salon 1 Etkinliği',
                kind: 'club_event',
                startsAt: now.add(const Duration(hours: 1)),
                endsAt: now.add(const Duration(hours: 2)),
                status: 'confirmed',
                fee: 0,
              ),
            ],
          ),
          narrowFacilityReservationsProvider(fac2Id).overrideWith(
            (ref) async => [
              FacilityReservation(
                id: 'res-fac2',
                clubId: 'club-1',
                facilityId: fac2Id,
                title: 'Salon 2 Etkinliği',
                kind: 'maintenance',
                startsAt: now.add(const Duration(hours: 3)),
                endsAt: now.add(const Duration(hours: 4)),
                status: 'pending',
                fee: 0,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityReservationsScreen(
            initialFacilityId: validFacId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salon 1 Etkinliği'), findsOneWidget);
      expect(find.text('Salon 2 Etkinliği'), findsNothing);

      // Open dropdown and select Salon 2
      await tester.tap(find.byKey(const Key('facility-reservations-dropdown')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salon 2 (Müsait)').last);
      await tester.pumpAndSettle();

      expect(find.text('Salon 2 Etkinliği'), findsOneWidget);
      expect(find.text('Salon 1 Etkinliği'), findsNothing);
    });

    testWidgets('async load completed after dispose does not crash',
        (tester) async {
      final completer = Completer<List<FacilityReservation>>();

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.facilityConflicts}),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'coach',
            ),
          ),
          facilitiesProvider.overrideWith(
            (ref) async => const [
              FacilityRow(
                id: validFacId,
                occupancy: 0,
                name: 'Anadolu Salonu',
                status: 'Müsait',
              ),
            ],
          ),
          narrowFacilityReservationsProvider(validFacId).overrideWith(
            (ref) => completer.future,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityReservationsScreen(
            initialFacilityId: validFacId,
          ),
        ),
      );
      await tester.pump(); // In loading state

      // Unmount
      await tester.pumpWidget(const SizedBox.shrink());

      completer.complete([]);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('responsive 320px layout and touch targets >= 48dp',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.facilityConflicts}),
          ),
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club-1',
              name: 'Anadolu SK',
              role: 'coach',
            ),
          ),
          facilitiesProvider.overrideWith(
            (ref) async => const [
              FacilityRow(
                id: validFacId,
                occupancy: 0,
                name: 'Anadolu Salonu',
                status: 'Müsait',
              ),
            ],
          ),
          narrowFacilityReservationsProvider(validFacId).overrideWith(
            (ref) async => [
              FacilityReservation(
                id: 'res-resp',
                clubId: 'club-1',
                facilityId: validFacId,
                title: 'Çok Uzun Başlıklı Bir Rezervasyon Kaydı Testi',
                kind: 'club_event',
                startsAt: DateTime.now().add(const Duration(hours: 1)),
                endsAt: DateTime.now().add(const Duration(hours: 2)),
                status: 'confirmed',
                fee: 0,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildHost(
          container: container,
          textScaleFactor: 2.0,
          child: const SharedFacilityReservationsScreen(
            initialFacilityId: validFacId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final dropdown = find.byKey(const Key('facility-reservations-dropdown'));
      final size = tester.getSize(dropdown);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}

Widget _buildHost({
  required ProviderContainer container,
  required Widget child,
  ProFeatureNavigator? navigator,
  double textScaleFactor = 1.0,
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, appChild) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: appChild!,
        ),
        home: ProFeatureHostScope(
          navigator: navigator ?? _RecordingNavigator(),
          chrome: const _TestChrome(),
          theme: ProFeatureThemeData.light,
          child: Scaffold(body: child),
        ),
      ),
    );

final class _RecordingNavigator extends ProFeatureNavigatorBase {
  @override
  void openAttendance() {}
  @override
  void openAttendanceHistory() {}
  @override
  void openRoster(TeamRouteTarget target) {}
  @override
  void openTeams() {}
  @override
  void openTrainingBuilder() {}
  @override
  void openTrainingList() {}
  @override
  void openTrainingProtocols() {}
  @override
  void openTrainingResult({String? sessionId}) {}
  @override
  void openTrainingSession({String? sessionId}) {}
  @override
  void openFinanceOperations() {}
  @override
  void openFinanceLedger() {}
  @override
  void openFinanceCommitments() {}
  @override
  void openBankReconciliation() {}
  @override
  void openClubBudget() {}
  @override
  void openPeriodClosing() {}
  @override
  void openFacilityOperations() {}
}

final class _TestChrome implements ProFeatureChrome {
  const _TestChrome();

  @override
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
    Widget? bottomBar,
    bool allowBack = true,
  }) =>
      Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: body,
        bottomNavigationBar: bottomBar,
      );

  @override
  Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
  }) async =>
      true;

  @override
  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone = ProFeatureMessageTone.info,
  }) {}
}
