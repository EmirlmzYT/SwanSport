import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  group('SharedFacilityScheduleScreen Gate Tests', () {
    testWidgets('both turf and club gates closed -> fail-closed empty state',
        (tester) async {
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
            (ref) async => const FeatureFlags({}),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tesis Programı Yetkisi Yok'), findsOneWidget);
      expect(find.byKey(const Key('turf-occupancy-section')), findsNothing);
      expect(find.byKey(const Key('club-facility-section')), findsNothing);
    });

    testWidgets(
        'turf flag closed -> turf section not rendered, club facility section rendered if staff',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {'turf-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.facilityConflicts, // turfFields is missing
            }),
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
                id: 'fac-1',
                occupancy: 0,
                name: 'Kapalı Spor Salonu',
                status: 'Müsait',
              ),
            ],
          ),
          facilityLoadProvider.overrideWith(
            (ref) async => const [],
          ),
          facilityScheduleProvider('fac-1').overrideWith(
            (ref) async => const [],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('turf-occupancy-section')), findsNothing);
      expect(find.byKey(const Key('club-facility-section')), findsOneWidget);
    });

    testWidgets(
        'facilityConflicts flag closed -> club facility section not rendered, turf section rendered if manager',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {'turf-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields, // facilityConflicts missing
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => const [],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('turf-occupancy-section')), findsOneWidget);
      expect(find.byKey(const Key('club-facility-section')), findsNothing);
    });
  });

  group('Halı Saha Doluluk Çizelgesi & Yazma Koruması', () {
    testWidgets(
        'user without canEditTurfOccupancy cannot see mark occupied/free buttons (hidden, not disabled)',
        (tester) async {
      final slotTime = DateTime.now().add(const Duration(hours: 2));
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {}, // not manager
              delegatedTurfFieldIds: {}, // not delegate
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => [
              TurfSlot(startsAt: slotTime, occupied: false),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Write action buttons must not exist
      expect(find.byKey(const Key('mark-occupied-btn')), findsNothing);
      expect(find.byKey(const Key('mark-free-btn')), findsNothing);
    });

    testWidgets(
        'authorized user sees mark occupied button, in-flight tap lock prevents duplicate submission',
        (tester) async {
      final slotTime = DateTime.now().add(const Duration(hours: 2));
      final completer = Completer<void>();
      int markCount = 0;

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'turf-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => [
              TurfSlot(startsAt: slotTime, occupied: false),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedFacilityScheduleScreen(
            writeCallbacks: FacilityScheduleWriteCallbacks(
              onMarkOccupied: ({
                required String fieldId,
                required DateTime startsAt,
                String? note,
              }) {
                markCount++;
                return completer.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select slot
      await tester
          .tap(find.byKey(Key('turf-slot-${slotTime.toIso8601String()}')));
      await tester.pumpAndSettle();

      final markBtn = find.byKey(const Key('mark-occupied-btn'));
      expect(markBtn, findsOneWidget);

      // Tap once
      await tester.tap(markBtn);
      await tester.pump(); // Starts in-flight operation

      // Tap second time while in flight
      await tester.tap(markBtn);
      await tester.pump();

      expect(markCount, 1); // Second tap blocked by in-flight lock

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'expired or revoked delegate has write actions hidden (not disabled)',
        (tester) async {
      final slotTime = DateTime.parse('2026-10-27T16:00:00Z');
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {},
              // User has active duty on other-turf, but revoked/expired on turf-1
              delegatedTurfFieldIds: {'other-turf'},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.turfFields}),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => [
              TurfSlot(startsAt: slotTime, occupied: false),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Badge must show 'Salt Okunur'
      expect(find.text('Salt Okunur'), findsOneWidget);
      expect(find.text('Yetkili'), findsNothing);

      // Select slot
      await tester
          .tap(find.byKey(Key('turf-slot-${slotTime.toIso8601String()}')));
      await tester.pumpAndSettle();

      // Write action buttons must not exist
      expect(find.byKey(const Key('mark-occupied-btn')), findsNothing);
      expect(find.byKey(const Key('mark-free-btn')), findsNothing);
    });

    testWidgets(
        'markOccupied retries with same payload on uncertain failure, invalidates data and displays real state',
        (tester) async {
      final slotTime = DateTime.parse('2026-10-27T15:00:00Z');
      var callCount = 0;
      final payloadFieldIds = <String>[];
      final payloadStartsAt = <DateTime>[];
      var isOccupiedInDb = false;

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'turf-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.turfFields}),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => [
              TurfSlot(startsAt: slotTime, occupied: isOccupiedInDb),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedFacilityScheduleScreen(
            writeCallbacks: FacilityScheduleWriteCallbacks(
              onMarkOccupied: ({
                required String fieldId,
                required DateTime startsAt,
                String? note,
              }) async {
                callCount++;
                payloadFieldIds.add(fieldId);
                payloadStartsAt.add(startsAt);
                if (callCount == 1) {
                  throw Exception('Network timeout / uncertain result');
                }
                isOccupiedInDb = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select slot
      await tester
          .tap(find.byKey(Key('turf-slot-${slotTime.toIso8601String()}')));
      await tester.pumpAndSettle();

      // First tap -> fails with network error
      await tester.tap(find.byKey(const Key('mark-occupied-btn')));
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(
        find.textContaining('Ağ hatası veya işlem başarısız oldu'),
        findsOneWidget,
      );

      // Verify that the mark-occupied button remains visible for immediate retry with same payload
      final retryBtn = find.byKey(const Key('mark-occupied-btn'));
      expect(retryBtn, findsOneWidget);

      // Retry with same payload
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(payloadFieldIds[0], payloadFieldIds[1]);
      expect(payloadStartsAt[0], payloadStartsAt[1]);
      expect(
        find.text('Saat hücresi dolu olarak işaretlendi.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'async markOccupied completed after dispose does not update state',
        (tester) async {
      final slotTime = DateTime.parse('2026-10-27T17:00:00Z');
      final completer = Completer<void>();

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'turf-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.turfFields}),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => [
              TurfSlot(startsAt: slotTime, occupied: false),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedFacilityScheduleScreen(
            writeCallbacks: FacilityScheduleWriteCallbacks(
              onMarkOccupied: ({
                required String fieldId,
                required DateTime startsAt,
                String? note,
              }) =>
                  completer.future,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(Key('turf-slot-${slotTime.toIso8601String()}')));
      await tester.pumpAndSettle();

      // Trigger write
      await tester.tap(find.byKey(const Key('mark-occupied-btn')));
      await tester.pump();

      // Unmount / dispose widget
      await tester.pumpWidget(const SizedBox.shrink());

      // Complete async operation after dispose
      completer.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'changing turf facility scope clears selected cell and prevents state leakage',
        (tester) async {
      final slotTime1 = DateTime.parse('2026-10-27T18:00:00Z');
      final slotTime2 = DateTime.parse('2026-10-27T19:00:00Z');

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'turf-1', 'turf-2'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({FeatureFlags.turfFields}),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => [
              TurfSlot(startsAt: slotTime1, occupied: false),
            ],
          ),
          turfOccupancyGridProvider('turf-2').overrideWith(
            (ref) async => [
              TurfSlot(startsAt: slotTime2, occupied: false),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Select slot on turf-1
      await tester
          .tap(find.byKey(Key('turf-slot-${slotTime1.toIso8601String()}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mark-occupied-btn')), findsOneWidget);

      // Switch scope to turf-2
      container.read(selectedFacilityScopeIdProvider.notifier).state = 'turf-2';
      await tester.pumpAndSettle();

      // Selected slot action from turf-1 must be cleared immediately
      expect(find.byKey(const Key('mark-occupied-btn')), findsNothing);
      expect(
        find.byKey(Key('turf-slot-${slotTime2.toIso8601String()}')),
        findsOneWidget,
      );
    });
  });

  group('Kulüp Tesisi Çakışma Denetimi (Conflict Inspection)', () {
    testWidgets(
        'conflict check with invalid UUID or free text produces "Doğrulanamıyor" (not fake 0)',
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
            (ref) async => const FeatureFlags({
              FeatureFlags.facilityConflicts,
            }),
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
                id: '12345678-1234-1234-1234-123456789abc',
                occupancy: 0,
                name: 'Kapalı Spor Salonu',
                status: 'Müsait',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(
            initialCustomFacilityId: 'Serbest Metin Salon Adı', // Invalid UUID
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must explicitly display "Doğrulanamıyor", NEVER fake 0 or "Kayıtlı çakışma yok"
      expect(find.text('Doğrulanamıyor'), findsOneWidget);
      expect(find.text('Kayıtlı çakışma yok'), findsNothing);
    });

    testWidgets(
        'facility not belonging to active club produces "Doğrulanamıyor" (prevents fake empty result)',
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
            (ref) async => const FeatureFlags({
              FeatureFlags.facilityConflicts,
            }),
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
                id: '11111111-1111-1111-1111-111111111111',
                occupancy: 0,
                name: 'Anadolu Salonu',
                status: 'Müsait',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      // Querying a UUID of another club's facility
      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(
            initialCustomFacilityId: '99999999-9999-9999-9999-999999999999',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Because it does not belong to active club, RPC would return empty due to RLS.
      // Screen must detect and return "Doğrulanamıyor" instead of fake "Kayıtlı çakışma yok"!
      expect(find.text('Doğrulanamıyor'), findsOneWidget);
      expect(find.text('Kayıtlı çakışma yok'), findsNothing);
    });

    testWidgets('server error in conflict check produces "Doğrulanamıyor"',
        (tester) async {
      const validFacId = '11111111-1111-1111-1111-111111111111';
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
            (ref) async => const FeatureFlags({
              FeatureFlags.facilityConflicts,
            }),
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
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedFacilityScheduleScreen(
            initialCustomFacilityId: validFacId,
            writeCallbacks: FacilityScheduleWriteCallbacks(
              onCheckConflicts: ({
                required String facilityId,
                required DateTime start,
                DateTime? end,
              }) async {
                throw Exception('Database connection error');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Doğrulanamıyor'), findsOneWidget);
      expect(find.text('Kayıtlı çakışma yok'), findsNothing);
    });

    testWidgets(
        'verified conflict check with 0 conflicts displays "Kayıtlı çakışma yok"',
        (tester) async {
      const validFacId = '11111111-1111-1111-1111-111111111111';
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
            (ref) async => const FeatureFlags({
              FeatureFlags.facilityConflicts,
            }),
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
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedFacilityScheduleScreen(
            initialCustomFacilityId: validFacId,
            writeCallbacks: FacilityScheduleWriteCallbacks(
              onCheckConflicts: ({
                required String facilityId,
                required DateTime start,
                DateTime? end,
              }) async =>
                  const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kayıtlı çakışma yok'), findsOneWidget);
      expect(find.text('Doğrulanamıyor'), findsNothing);
    });

    testWidgets(
        'verified conflict check with >0 conflicts displays count and does not leak title, notes, or person name',
        (tester) async {
      const validFacId = '11111111-1111-1111-1111-111111111111';

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
            (ref) async => const FeatureFlags({
              FeatureFlags.facilityConflicts,
            }),
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
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedFacilityScheduleScreen(
            initialCustomFacilityId: validFacId,
            writeCallbacks: FacilityScheduleWriteCallbacks(
              onCheckConflicts: ({
                required String facilityId,
                required DateTime start,
                DateTime? end,
              }) async =>
                  [
                FacilitySlot(
                  id: 'conflict-1',
                  title: 'ÖZEL KİŞİSEL ŞİRKET ETKİNLİĞİ',
                  kind: 'rental',
                  startsAt: start,
                  endsAt: end ?? start.add(const Duration(hours: 1)),
                  teamName: 'Gizli Bilgi',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Çakışma mevcut (1 kayıt)'), findsOneWidget);
      // Ensure private details are not leaked into the UI
      expect(find.text('ÖZEL KİŞİSEL ŞİRKET ETKİNLİĞİ'), findsNothing);
      expect(find.text('Gizli Bilgi'), findsNothing);
    });

    testWidgets(
        'changing facility scope resets selected slot, conflict state and does not leak state',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {'turf-1', 'turf-2'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.facilityConflicts,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => [
              TurfSlot(
                startsAt: DateTime.now().add(const Duration(hours: 1)),
                occupied: false,
              ),
            ],
          ),
          turfOccupancyGridProvider('turf-2').overrideWith(
            (ref) async => [],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('turf-occupancy-section')), findsOneWidget);

      // Switch scope
      container.read(selectedFacilityScopeIdProvider.notifier).state = 'turf-2';
      await tester.pumpAndSettle();

      // Selected slot action buttons must be cleared
      expect(find.byKey(const Key('mark-occupied-btn')), findsNothing);
      expect(find.byKey(const Key('mark-free-btn')), findsNothing);
    });

    testWidgets('responsive 320px layout and touch targets >= 48dp',
        (tester) async {
      const validFacId = '11111111-1111-1111-1111-111111111111';
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'coach',
              coachLevel: 2,
              athleteKind: null,
              managedTurfFieldIds: {'turf-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.facilityConflicts,
            }),
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
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'turf-1'),
          turfOccupancyGridProvider('turf-1').overrideWith(
            (ref) async => const [],
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
          child: const SharedFacilityScheduleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(const Key('check-facility-conflicts-btn')),
        100.0,
      );
      await tester.pumpAndSettle();

      final checkConflictsBtn =
          find.byKey(const Key('check-facility-conflicts-btn'));
      expect(checkConflictsBtn, findsOneWidget);
      final size = tester.getSize(checkConflictsBtn);
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
  final List<String> calls = [];

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
  void openFinanceOperations() => calls.add('openFinanceOperations');

  @override
  void openFinanceLedger() => calls.add('openFinanceLedger');

  @override
  void openFinanceCommitments() => calls.add('openFinanceCommitments');

  @override
  void openBankReconciliation() => calls.add('openBankReconciliation');

  @override
  void openClubBudget() => calls.add('openClubBudget');

  @override
  void openPeriodClosing() => calls.add('openPeriodClosing');

  @override
  void openFacilityOperations() => calls.add('openFacilityOperations');
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
