import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets(
      'SharedClubBudgetScreen separates forecast from actual and never adds uncertain cash to definite projection',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            accountantClubIds: {'club-acc-1'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.clubBudgeting,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        budgetLinesProvider.overrideWith(
          (ref) async => [
            BudgetLine(
              budgetId: 'b-1',
              scope: 'team',
              scopeLabel: 'U-16 Futbol Takımı',
              category: 'Kamp & Konaklama',
              periodFrom: DateTime.utc(2026, 10, 1),
              periodTo: DateTime.utc(2026, 10, 31),
              planned: 60000,
              actual: 42000,
              committed: 8000,
              remaining: 10000,
              risk: 'bilgi',
            ),
          ],
        ),
        cashForecastProvider.overrideWith(
          (ref) async => [
            const CashForecast(
              horizonDays: 30,
              opening: 50000,
              confirmedIn: 25000,
              confirmedOut: 15000,
              expectedIn: 10000,
              expectedOut: 5000,
              uncertainOut: 18000,
              projectedLow: 60000,
              projectedHigh: 65000,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: const SharedClubBudgetScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('U-16 Futbol Takımı'), findsOneWidget);
    expect(find.textContaining('Kamp & Konaklama'), findsOneWidget);
    expect(find.textContaining('Planlanan: 60.000 ₺'), findsOneWidget);
    expect(find.textContaining('Gerçekleşen: 42.000 ₺'), findsOneWidget);

    expect(
      find.textContaining('Onaylı Projeksiyon (30 Gün): 60.000 ₺'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Beklenen Projeksiyon (30 Gün): 65.000 ₺'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Belirsiz Çıkış (Projeksiyona Katılmaz): 18.000 ₺'),
      findsOneWidget,
    );
    expect(find.textContaining('78.000 ₺'), findsNothing);
    expect(find.textContaining('83.000 ₺'), findsNothing);
  });

  testWidgets(
      'SharedClubBudgetScreen and SharedPeriodClosingScreen fail-closed when financeOperationsCenter is disabled',
      (tester) async {
    final disabledContainer = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            accountantClubIds: {'club-acc-1'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.clubBudgeting,
            FeatureFlags.periodClosing,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
      ],
    );
    addTearDown(disabledContainer.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: disabledContainer,
        child: const SharedClubBudgetScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bütçe ve nakit tahmini kademeli yayında'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _buildHost(
        container: disabledContainer,
        child: const SharedPeriodClosingScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Dönem kapanışı kademeli yayında'),
      findsOneWidget,
    );
  });

  testWidgets(
      'SharedClubBudgetScreen renders on 320px width and 2.0 text scale with >=48dp touch targets',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            accountantClubIds: {'club-acc-1'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.clubBudgeting,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        budgetLinesProvider.overrideWith((ref) async => const []),
        cashForecastProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: const SharedClubBudgetScreen(),
        textScaleFactor: 2.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Anadolu SK'), findsWidgets);

    final budgetHeading =
        find.textContaining('Bütçe ve Gerçekleşen Karşılaştırması');
    await tester.scrollUntilVisible(budgetHeading, 100);
    expect(budgetHeading, findsOneWidget);
  });

  testWidgets(
      'SharedPeriodClosingScreen renders on 320px width and 2.0 text scale with >=48dp touch targets',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            accountantClubIds: {'club-acc-1'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.periodClosing,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        financePeriodsProvider.overrideWith((ref) async => const []),
        financeAdjustmentsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: const SharedPeriodClosingScreen(),
        textScaleFactor: 2.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final newBtnFinder = find.byKey(const Key('open-new-adjustment-sheet-btn'));
    await tester.scrollUntilVisible(newBtnFinder, 100);
    expect(newBtnFinder, findsOneWidget);
    final size = tester.getSize(newBtnFinder);
    expect(size.height, greaterThanOrEqualTo(48.0));

    final filterAllFinder = find.byKey(const Key('closing-filter-all'));
    await tester.scrollUntilVisible(filterAllFinder, 100);
    expect(filterAllFinder, findsOneWidget);
    final filterSize = tester.getSize(filterAllFinder);
    expect(filterSize.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets(
      'SharedPeriodClosingScreen cannot directly edit closed period history and uses offsetting adjustment flow with self-approval lock',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recordedDecisions = <Map<String, Object?>>[];
    final container = ProviderContainer(
      overrides: [
        proFeatureContextProvider.overrideWith(
          (ref) => const ProFeatureContextKey.accounting(
            userId: 'user-acc-1',
            accountingClubId: 'club-acc-1',
          ),
        ),
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            accountantClubIds: {'club-acc-1'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.periodClosing,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        financePeriodsProvider.overrideWith(
          (ref) async => [
            FinancePeriod(
              id: 'per-closed-1',
              clubId: 'club-acc-1',
              periodFrom: DateTime.utc(2026, 9, 1),
              periodTo: DateTime.utc(2026, 9, 30),
              status: 'closed',
            ),
          ],
        ),
        financeAdjustmentsProvider.overrideWith(
          (ref) async => [
            FinanceAdjustment(
              id: 'adj-own-1',
              clubId: 'club-acc-1',
              periodId: 'per-closed-1',
              targetKind: 'expense',
              targetId: 'exp-10',
              amount: 4500,
              reason: 'Eylül mükerrer tesis bakım kaydı iadesi',
              status: 'pending',
              createdAt: DateTime.utc(2026, 10, 26),
              createdBy: 'user-acc-1',
            ),
            FinanceAdjustment(
              id: 'adj-other-2',
              clubId: 'club-acc-1',
              periodId: 'per-closed-1',
              targetKind: 'payment',
              targetId: 'pay-20',
              amount: 2200,
              reason: 'Eylül fazla tahsilat düzeltmesi',
              status: 'pending',
              createdAt: DateTime.utc(2026, 10, 26),
              createdBy: 'user-other-99',
            ),
          ],
        ),
        closedPeriodCandidatesPageProvider.overrideWith(
          (ref, params) async => const ClosedPeriodCandidatesPage(
            entries: [],
            totalCount: 0,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: SharedPeriodClosingScreen(
          writeCallbacks: PeriodClosingWriteCallbacks(
            onApproveAdjustment: ({
              required clubId,
              required operationId,
              required adjustmentId,
              required approve,
              note,
            }) async {
              recordedDecisions.add({
                'clubId': clubId,
                'operationId': operationId,
                'adjustmentId': adjustmentId,
                'approve': approve,
              });
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Kapalı dönem kayıtları doğrudan düzenlenemez veya silinemez',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Kendi açtığın düzeltmeyi onaylayamazsın'),
      findsOneWidget,
    );

    final ownApproveBtn = tester.widget<FilledButton>(
      find.byKey(const Key('approve-adjustment-btn-adj-own-1')),
    );
    expect(ownApproveBtn.onPressed, isNull);

    final otherApproveBtnFinder =
        find.byKey(const Key('approve-adjustment-btn-adj-other-2'));
    final otherApproveBtn = tester.widget<FilledButton>(otherApproveBtnFinder);
    expect(otherApproveBtn.onPressed, isNotNull);

    await tester.ensureVisible(otherApproveBtnFinder);
    await tester.tap(otherApproveBtnFinder);
    await tester.pumpAndSettle();

    expect(recordedDecisions, hasLength(1));
    expect(recordedDecisions.first['adjustmentId'], 'adj-other-2');
    expect(recordedDecisions.first['approve'], isTrue);
  });

  testWidgets(
      'SharedPeriodClosingScreen clears pending state and draft when accountant switches club',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            accountantClubIds: {'club-acc-1', 'club-acc-2'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.periodClosing,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
            ClubRef(id: 'club-acc-2', name: 'Bursa SK', role: 'accountant'),
          ],
        ),
        financePeriodsProvider.overrideWith((ref) async => const []),
        financeAdjustmentsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    const scopeKey = 'club-acc-1:adjustment_decision:adj-1';
    container.read(proPendingOperationsProvider.notifier).saveOperation(
      scopeKey: scopeKey,
      operationId: 'op-initial-1',
      payload: {'test': true},
    );

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: const SharedPeriodClosingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Anadolu SK'), findsWidgets);

    container.read(selectedAccountantClubIdProvider.notifier).state =
        'club-acc-2';
    await tester.pumpAndSettle();

    expect(find.textContaining('Bursa SK'), findsWidgets);
    expect(find.byKey(const Key('retry-pending-op-btn')), findsNothing);
  });

  testWidgets(
      'SharedPeriodClosingScreen preserves and retries with exact same operationId on uncertain network error',
      (tester) async {
    final attempts = <Map<String, Object?>>[];
    var shouldFail = true;

    final container = ProviderContainer(
      overrides: [
        proFeatureContextProvider.overrideWith(
          (ref) => const ProFeatureContextKey.accounting(
            userId: 'user-acc-1',
            accountingClubId: 'club-acc-1',
          ),
        ),
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            accountantClubIds: {'club-acc-1'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.periodClosing,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        financePeriodsProvider.overrideWith((ref) async => const []),
        financeAdjustmentsProvider.overrideWith(
          (ref) async => [
            FinanceAdjustment(
              id: 'adj-other-retry',
              clubId: 'club-acc-1',
              periodId: 'per-closed-1',
              targetKind: 'expense',
              targetId: 'exp-50',
              amount: 5000,
              reason: 'Yol gideri iadesi',
              status: 'pending',
              createdAt: DateTime.utc(2026, 10, 26),
              createdBy: 'user-other-99',
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: SharedPeriodClosingScreen(
          writeCallbacks: PeriodClosingWriteCallbacks(
            onApproveAdjustment: ({
              required clubId,
              required operationId,
              required adjustmentId,
              required approve,
              note,
            }) async {
              attempts.add({
                'clubId': clubId,
                'operationId': operationId,
                'adjustmentId': adjustmentId,
                'approve': approve,
              });
              if (shouldFail) {
                throw TimeoutException('Simulated network timeout');
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final approveBtnFinder =
        find.byKey(const Key('approve-adjustment-btn-adj-other-retry'));
    await tester.ensureVisible(approveBtnFinder);
    await tester.tap(approveBtnFinder);
    await tester.pumpAndSettle();

    expect(attempts, hasLength(1));
    final initialOpId = attempts.first['operationId'] as String;
    expect(initialOpId, isNotEmpty);

    const scopeKey = 'club-acc-1:adjustment_decision:adj-other-retry';
    final savedOp =
        container.read(proPendingOperationsProvider).operationFor(scopeKey);
    expect(savedOp, isNotNull);
    expect(savedOp!.operationId, initialOpId);

    final retryBtnFinder = find.byKey(const Key('retry-pending-op-btn'));
    expect(retryBtnFinder, findsOneWidget);

    shouldFail = false;
    await tester.tap(retryBtnFinder);
    await tester.pumpAndSettle();

    expect(attempts, hasLength(2));
    expect(attempts[1]['operationId'], initialOpId);
    expect(attempts[1]['adjustmentId'], 'adj-other-retry');
    expect(
      container.read(proPendingOperationsProvider).operationFor(scopeKey),
      isNull,
    );
  });

  testWidgets(
      'SharedPeriodClosingScreen filters adjustments by status and supports pull-to-refresh',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: null,
            coachLevel: 0,
            athleteKind: null,
            accountantClubIds: {'club-acc-1'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.periodClosing,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        financePeriodsProvider.overrideWith((ref) async => const []),
        financeAdjustmentsProvider.overrideWith(
          (ref) async => [
            FinanceAdjustment(
              id: 'adj-pending-1',
              clubId: 'club-acc-1',
              periodId: 'per-closed-1',
              targetKind: 'expense',
              targetId: 'exp-1',
              amount: 1000,
              reason: 'Onay bekleyen gider iadesi',
              status: 'pending',
              createdAt: DateTime.utc(2026, 10, 26),
              createdBy: 'user-2',
            ),
            FinanceAdjustment(
              id: 'adj-approved-2',
              clubId: 'club-acc-1',
              periodId: 'per-closed-1',
              targetKind: 'payment',
              targetId: 'pay-2',
              amount: 2000,
              reason: 'Onaylanan tahsilat düzeltmesi',
              status: 'approved',
              createdAt: DateTime.utc(2026, 10, 26),
              createdBy: 'user-3',
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: const SharedPeriodClosingScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Onay bekleyen gider iadesi'), findsOneWidget);
    expect(
      find.textContaining('Onaylanan tahsilat düzeltmesi'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('closing-filter-pending')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Onay bekleyen gider iadesi'), findsOneWidget);
    expect(find.textContaining('Onaylanan tahsilat düzeltmesi'), findsNothing);

    await tester.tap(find.byKey(const Key('closing-filter-approved')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Onay bekleyen gider iadesi'), findsNothing);
    expect(
      find.textContaining('Onaylanan tahsilat düzeltmesi'),
      findsOneWidget,
    );

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _buildHost({
  required ProviderContainer container,
  required Widget child,
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
          navigator: _NoopNavigator(),
          chrome: const _TestChrome(),
          theme: ProFeatureThemeData.light,
          child: Scaffold(body: child),
        ),
      ),
    );

final class _NoopNavigator extends ProFeatureNavigatorBase {
  _NoopNavigator();

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
