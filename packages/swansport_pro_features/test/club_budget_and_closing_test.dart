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
}

Widget _buildHost({
  required ProviderContainer container,
  required Widget child,
}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
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
