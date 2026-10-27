import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  group('SharedFacilityOperationsPanel Tests', () {
    testWidgets(
        'canOpenTurfCenter is false -> shows fail-closed unauthorized empty state and no query',
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
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityOperationsPanel(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tesis Operasyonları Yetkisi Yok'), findsOneWidget);
      expect(find.byKey(const Key('facility-scope-selector')), findsNothing);
    });

    testWidgets(
        'managedTurfFieldIds and delegatedTurfFieldIds are separately displayed in scope selector',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-mgr-1'},
              delegatedTurfFieldIds: {'field-del-1'},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          turfFieldsProvider(null).overrideWith(
            (ref) async => const [
              TurfField(
                id: 'field-mgr-1',
                name: 'Kuzey Halı Saha',
                venueName: 'Kuzey Spor Kompleksi',
                opensAt: '09:00',
                closesAt: '23:00',
              ),
              TurfField(
                id: 'field-del-1',
                name: 'Güney Halı Saha',
                venueName: 'Güney Spor Tesisleri',
                opensAt: '10:00',
                closesAt: '22:00',
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedFacilityOperationsPanel(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('facility-scope-selector')), findsOneWidget);
      await tester.tap(find.byKey(const Key('facility-scope-selector')));
      await tester.pumpAndSettle();

      expect(find.text('Yönetici'), findsWidgets);
      expect(find.text('Görevli Delege'), findsWidgets);
    });

    testWidgets('turf feature flags disabled -> fail-closed banner',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
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
          child: const SharedFacilityOperationsPanel(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Tesis operasyonları özelliği etkin değil.'),
        findsOneWidget,
      );
    });
  });

  group('SharedManagedTurfDutiesScreen Tests', () {
    testWidgets('manager sees create duty invite button', (tester) async {
      final managerContainer = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => const TurfDutyPage([], false),
          ),
        ],
      );
      addTearDown(managerContainer.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: managerContainer,
          child: const SharedManagedTurfDutiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('create-duty-invite-btn')), findsOneWidget);
    });

    testWidgets(
        'non-manager delegate DOES NOT see create duty invite button (hidden, not disabled)',
        (tester) async {
      final delegateContainer = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {'field-1'},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => const TurfDutyPage([], false),
          ),
        ],
      );
      addTearDown(delegateContainer.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: delegateContainer,
          child: const SharedManagedTurfDutiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Must be completely HIDDEN, not disabled
      expect(find.byKey(const Key('create-duty-invite-btn')), findsNothing);
    });

    testWidgets(
        'delegate user DOES NOT see revoke button on duty card (hidden, not disabled)',
        (tester) async {
      final now = DateTime.now();
      final duty = TurfDuty(
        id: 'duty-active-1',
        fieldId: 'field-1',
        fieldName: 'Kuzey Halı Saha',
        venueName: 'Kuzey Spor Kompleksi',
        issuer: false, // user is delegate / recipient
        validUntil: now.add(const Duration(hours: 12)),
        inviteUntil: now.add(const Duration(hours: 6)),
        status: 'active',
      );

      final delegateContainer = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {},
              delegatedTurfFieldIds: {'field-1'},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => TurfDutyPage([duty], false),
          ),
        ],
      );
      addTearDown(delegateContainer.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: delegateContainer,
          child: const SharedManagedTurfDutiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Revoke action must be completely hidden for non-manager delegate
      expect(find.text('Görevi geri al'), findsNothing);
      expect(
        find.byKey(const Key('revoke-duty-btn-duty-active-1')),
        findsNothing,
      );
    });

    testWidgets('manager issuer sees revoke button on active duty',
        (tester) async {
      final now = DateTime.now();
      final duty = TurfDuty(
        id: 'duty-active-1',
        fieldId: 'field-1',
        fieldName: 'Kuzey Halı Saha',
        venueName: 'Kuzey Spor Kompleksi',
        issuer: true, // manager issuer
        validUntil: now.add(const Duration(hours: 12)),
        inviteUntil: now.add(const Duration(hours: 6)),
        status: 'active',
      );

      final managerContainer = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => TurfDutyPage([duty], false),
          ),
        ],
      );
      addTearDown(managerContainer.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: managerContainer,
          child: const SharedManagedTurfDutiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Görevi geri al'), findsOneWidget);
    });

    testWidgets('expired or revoked duty hides revoke action (fail-closed)',
        (tester) async {
      final now = DateTime.now();
      final revokedDuty = TurfDuty(
        id: 'duty-revoked-1',
        fieldId: 'field-1',
        fieldName: 'Kuzey Halı Saha',
        venueName: 'Kuzey Spor Kompleksi',
        issuer: true,
        validUntil: now.add(const Duration(hours: 12)),
        inviteUntil: now.add(const Duration(hours: 6)),
        status: 'revoked',
      );

      final expiredDuty = TurfDuty(
        id: 'duty-expired-1',
        fieldId: 'field-1',
        fieldName: 'Kuzey Halı Saha',
        venueName: 'Kuzey Spor Kompleksi',
        issuer: true,
        validUntil: now.subtract(const Duration(hours: 2)),
        inviteUntil: now.subtract(const Duration(hours: 4)),
        status: 'expired',
      );

      final managerContainer = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => TurfDutyPage([revokedDuty, expiredDuty], false),
          ),
        ],
      );
      addTearDown(managerContainer.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: managerContainer,
          child: const SharedManagedTurfDutiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Görevi geri al'), findsNothing);
      expect(find.text('Geri alındı'), findsOneWidget);
      expect(find.text('Süresi doldu'), findsOneWidget);
    });

    testWidgets(
        'server status takes priority: duty.status dictates label even if client clock is shifted',
        (tester) async {
      // Server returned status 'revoked', but client time validUntil is in the future
      final duty = TurfDuty(
        id: 'duty-server-truth',
        fieldId: 'field-1',
        fieldName: 'Kuzey Halı Saha',
        venueName: 'Kuzey Spor Kompleksi',
        issuer: true,
        validUntil: DateTime.now().add(const Duration(days: 10)),
        inviteUntil: DateTime.now().add(const Duration(days: 5)),
        status: 'revoked', // Server explicitly marked as revoked
      );

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => TurfDutyPage([duty], false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedManagedTurfDutiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // UI displays server truth
      expect(find.text('Geri alındı'), findsOneWidget);
      expect(find.text('Aktif görev'), findsNothing);
    });

    testWidgets(
        'changing facility scope invalidates data and resets local draft state',
        (tester) async {
      int fetchCount = 0;
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1', 'field-2'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith((ref) async {
            fetchCount++;
            return const TurfDutyPage([], false);
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: const SharedManagedTurfDutiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final initialFetchCount = fetchCount;
      expect(initialFetchCount, greaterThanOrEqualTo(1));

      // Change scope
      container.read(selectedFacilityScopeIdProvider.notifier).state =
          'field-2';
      await tester.pumpAndSettle();

      expect(fetchCount, greaterThan(initialFetchCount));
    });

    testWidgets(
        'idempotent retry reuses identical operationId and payload on uncertain network failure',
        (tester) async {
      String? firstOpId;
      String? secondOpId;
      int callCount = 0;

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => const TurfDutyPage([], false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedManagedTurfDutiesScreen(
            writeCallbacks: TurfDutiesWriteCallbacks(
              onCreateDuty: ({
                required String fieldId,
                required int hours,
                required String operationId,
              }) async {
                callCount++;
                if (callCount == 1) {
                  firstOpId = operationId;
                  throw Exception('Network timeout / uncertain result');
                }
                secondOpId = operationId;
                return TurfDutyInvite(
                  code: '12345678-1234-1234-1234-123456789abc',
                  validUntil: DateTime.now().add(Duration(hours: hours)),
                  inviteUntil: DateTime.now().add(const Duration(hours: 24)),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open create dialog
      await tester.tap(find.byKey(const Key('create-duty-invite-btn')));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('submit-create-duty-btn')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('retry-pending-duty-op-btn')),
        findsOneWidget,
      );
      expect(firstOpId, isNotNull);

      // Retry
      await tester.tap(find.byKey(const Key('retry-pending-duty-op-btn')));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      expect(secondOpId, equals(firstOpId));
    });

    testWidgets('redeem duty refreshes list upon success', (tester) async {
      bool redeemed = false;
      int dutiesFetched = 0;

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith((ref) async {
            dutiesFetched++;
            if (!redeemed) {
              return const TurfDutyPage([], false);
            }
            return TurfDutyPage(
              [
                TurfDuty(
                  id: 'duty-redeemed-new',
                  fieldId: 'field-1',
                  fieldName: 'Kuzey Halı Saha',
                  venueName: 'Kuzey Spor Kompleksi',
                  issuer: false,
                  validUntil: DateTime.now().add(const Duration(hours: 8)),
                  inviteUntil: DateTime.now().add(const Duration(hours: 4)),
                  status: 'active',
                ),
              ],
              false,
            );
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedManagedTurfDutiesScreen(
            writeCallbacks: TurfDutiesWriteCallbacks(
              onRedeemDuty: (code) async {
                redeemed = true;
                return 'duty-redeemed-new';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter code
      await tester.enterText(
        find.byKey(const Key('redeem-duty-code-input')),
        '12345678-1234-1234-1234-123456789abc',
      );
      await tester.tap(find.byKey(const Key('submit-redeem-duty-btn')));
      await tester.pumpAndSettle();

      expect(redeemed, isTrue);
      expect(dutiesFetched, greaterThanOrEqualTo(1));
      expect(find.text('Kuzey Halı Saha'), findsOneWidget);
      expect(find.text('Aktif görev'), findsOneWidget);
    });

    testWidgets(
        'dispose safe: async completion after dispose does not throw or call setState',
        (tester) async {
      final completer = Completer<TurfDutyInvite>();

      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => const TurfDutyPage([], false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _buildHost(
          container: container,
          child: SharedManagedTurfDutiesScreen(
            writeCallbacks: TurfDutiesWriteCallbacks(
              onCreateDuty: ({
                required String fieldId,
                required int hours,
                required String operationId,
              }) =>
                  completer.future,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog and submit
      await tester.tap(find.byKey(const Key('create-duty-invite-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit-create-duty-btn')));
      await tester.pump(); // Start async work

      // Unmount the widget tree before completer finishes
      await tester.pumpWidget(const SizedBox.shrink());

      // Now complete future after unmount
      completer.complete(
        TurfDutyInvite(
          code: '12345678-1234-1234-1234-123456789abc',
          validUntil: DateTime.now().add(const Duration(hours: 4)),
          inviteUntil: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      await tester.pump();

      // No exception thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('responsive 320px layout and touch targets >= 48dp',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'member',
              coachLevel: 0,
              athleteKind: null,
              managedTurfFieldIds: {'field-1'},
              delegatedTurfFieldIds: {},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.turfFields,
              FeatureFlags.turfDelegation,
            }),
          ),
          selectedFacilityScopeIdProvider.overrideWith((ref) => 'field-1'),
          turfDutiesProvider(0).overrideWith(
            (ref) async => const TurfDutyPage([], false),
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
          child: const SharedManagedTurfDutiesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify touch targets >= 48dp
      final createBtn = find.byKey(const Key('create-duty-invite-btn'));
      final size = tester.getSize(createBtn);
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
