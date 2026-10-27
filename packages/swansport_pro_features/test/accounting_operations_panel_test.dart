import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets(
      'club selector only lists authorized accountant clubs and updates selectedAccountantClubIdProvider',
      (tester) async {
    final navigator = _RecordingNavigator();
    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: 'coach',
            coachLevel: 2,
            athleteKind: null,
            accountantClubIds: {'club-acc-1', 'club-acc-2'},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.recurringExpenses,
            FeatureFlags.bankReconciliation,
            FeatureFlags.clubBudgeting,
            FeatureFlags.periodClosing,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(
              id: 'club-coach-only',
              name: 'Koçluk Kulübü (Yetkisiz)',
              role: 'coach',
            ),
            ClubRef(
              id: 'club-acc-1',
              name: 'Anadolu SK',
              city: 'İstanbul',
              role: 'accountant',
            ),
            ClubRef(
              id: 'club-acc-2',
              name: 'Boğaziçi SK',
              city: 'İstanbul',
              role: 'accountant',
            ),
          ],
        ),
        financeOperationsSummaryProvider.overrideWith(
          (ref) async => const FinanceOperationsSummary(
            draftExpenseCount: 2,
            draftExpenseTotal: 4500,
            pendingApprovalCount: 1,
            pendingApprovalTotal: 8000,
          ),
        ),
        accountBalancesProvider.overrideWith(
          (ref) async => const [
            AccountBalance(
              accountId: 'acc-1',
              name: 'Ana Banka',
              kind: 'bank',
              income: 50000,
              outgo: 18000,
              balance: 32000,
            ),
          ],
        ),
        cashForecastProvider.overrideWith(
          (ref) async => const [
            CashForecast(
              horizonDays: 30,
              opening: 32000,
              confirmedIn: 10000,
              confirmedOut: 4000,
              expectedIn: 5000,
              expectedOut: 2000,
              uncertainOut: 9500,
              projectedLow: 38000,
              projectedHigh: 41000,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        navigator: navigator,
        child: const SingleChildScrollView(
          child: SharedAccountingOperationsPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Koçluk Kulübü (Yetkisiz)'), findsNothing);
    expect(find.byKey(const Key('accountant-club-selector')), findsOneWidget);
    expect(container.read(selectedAccountantClubIdProvider), 'club-acc-1');

    await tester.tap(find.byKey(const Key('accountant-club-selector')));
    await tester.pumpAndSettle();

    expect(find.text('Koçluk Kulübü (Yetkisiz)'), findsNothing);
    expect(find.textContaining('Anadolu SK'), findsWidgets);
    expect(find.textContaining('Boğaziçi SK'), findsOneWidget);

    await tester.tap(find.textContaining('Boğaziçi SK').last);
    await tester.pumpAndSettle();

    expect(container.read(selectedAccountantClubIdProvider), 'club-acc-2');
    expect(container.read(selectedClubIdProvider), 'club-acc-2');
  });

  testWidgets(
      'runs zero finance or athlete queries when there is no active accountant club scope',
      (tester) async {
    var summaryCalls = 0;
    var ledgerCalls = 0;
    var balanceCalls = 0;
    var forecastCalls = 0;
    var athleteCalls = 0;

    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: 'club_admin',
            coachLevel: 3,
            athleteKind: null,
            accountantClubIds: {},
          ),
        ),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-1', name: 'Kulüp 1', role: 'club_admin'),
          ],
        ),
        financeOperationsSummaryProvider.overrideWith((ref) async {
          summaryCalls++;
          return const FinanceOperationsSummary.empty();
        }),
        clubLedgerPageProvider.overrideWith((ref, offset) async {
          ledgerCalls++;
          return const LedgerPage(entries: [], totalCount: 0);
        }),
        accountBalancesProvider.overrideWith((ref) async {
          balanceCalls++;
          return const [];
        }),
        cashForecastProvider.overrideWith((ref) async {
          forecastCalls++;
          return const [];
        }),
        clubAthletesProvider.overrideWith((ref) async {
          athleteCalls++;
          return const [];
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: const Column(
          children: [
            Expanded(child: SharedAccountingOperationsPanel()),
            Expanded(child: SharedFinanceOperationsScreen()),
            Expanded(child: SharedFinanceLedgerScreen()),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(summaryCalls, 0);
    expect(ledgerCalls, 0);
    expect(balanceCalls, 0);
    expect(forecastCalls, 0);
    expect(athleteCalls, 0);
    expect(
      find.textContaining('Muhasebe çalışma alanı yetkisi gerekli'),
      findsWidgets,
    );
  });

  testWidgets(
      'FeatureFlags.financeOperationsCenter fails closed when disabled or errored',
      (tester) async {
    var summaryCalls = 0;
    var ledgerCalls = 0;

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
          (ref) async => const FeatureFlags.none(),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        financeOperationsSummaryProvider.overrideWith((ref) async {
          summaryCalls++;
          return const FinanceOperationsSummary.empty();
        }),
        clubLedgerPageProvider.overrideWith((ref, offset) async {
          ledgerCalls++;
          return const LedgerPage(entries: [], totalCount: 0);
        }),
      ],
    );
    addTearDown(disabledContainer.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: disabledContainer,
        child: const SharedFinanceOperationsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(summaryCalls, 0);
    expect(ledgerCalls, 0);
    expect(find.textContaining('kademeli yayında'), findsOneWidget);

    final errorContainer = ProviderContainer(
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
          (ref) => Future<FeatureFlags>.error(StateError('flag failure')),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
      ],
    );
    addTearDown(errorContainer.dispose);

    await tester.pumpWidget(
      KeyedSubtree(
        key: UniqueKey(),
        child: _buildHost(
          container: errorContainer,
          child: const SharedFinanceLedgerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(summaryCalls, 0);
    expect(ledgerCalls, 0);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets(
      'displays confirmed, expected, and uncertain cash separately and never adds uncertain cash to definite balance',
      (tester) async {
    var athleteCalls = 0;
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
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        accountBalancesProvider.overrideWith(
          (ref) async => const [
            AccountBalance(
              accountId: 'acc-1',
              name: 'Ziraat Kasa',
              kind: 'bank',
              income: 40000,
              outgo: 15000,
              balance: 25000,
            ),
          ],
        ),
        cashForecastProvider.overrideWith(
          (ref) async => const [
            CashForecast(
              horizonDays: 30,
              opening: 25000,
              confirmedIn: 8000,
              confirmedOut: 3000,
              expectedIn: 4000,
              expectedOut: 1000,
              uncertainOut: 12345,
              projectedLow: 30000,
              projectedHigh: 33000,
            ),
          ],
        ),
        financeOperationsSummaryProvider.overrideWith(
          (ref) async => const FinanceOperationsSummary(
            draftExpenseCount: 1,
            draftExpenseTotal: 1200,
            overdueInvoiceCount: 2,
            overdueInvoiceTotal: 3400,
          ),
        ),
        receivablesProvider.overrideWith(
          (ref) async => const [
            Receivable(
              athleteCode: '#A3F91C',
              unpaidCount: 2,
              total: 3400,
            ),
          ],
        ),
        clubAthletesProvider.overrideWith((ref) async {
          athleteCalls++;
          return const [
            AthleteRow(
              id: 'secret-athlete-uuid',
              firstName: 'Gizli',
              lastName: 'Sporcu',
            ),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: const SharedFinanceOperationsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(athleteCalls, 0);
    expect(find.textContaining('Gizli Sporcu'), findsNothing);
    expect(find.textContaining('secret-athlete-uuid'), findsNothing);

    // Definite balance is 25.000 ₺; confirmed projection is 30.000 ₺;
    // expected projection is 33.000 ₺; uncertain is 12.345 ₺ (never subtracted/added to 25.000/30.000/33.000).
    expect(
      find.byKey(const Key('finance-confirmed-cash-card')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('finance-expected-cash-card')), findsOneWidget);
    expect(
      find.byKey(const Key('finance-uncertain-cash-card')),
      findsOneWidget,
    );
    expect(find.textContaining('25.000 ₺'), findsWidgets);
    expect(find.textContaining('30.000 ₺'), findsWidgets);
    expect(find.textContaining('33.000 ₺'), findsWidgets);
    expect(find.textContaining('12.345 ₺'), findsOneWidget);
    // 25000 - 12345 = 12655 or 30000 - 12345 = 17655 or 33000 - 12345 = 20655 must NEVER appear:
    expect(find.textContaining('12.655'), findsNothing);
    expect(find.textContaining('17.655'), findsNothing);
    expect(find.textContaining('20.655'), findsNothing);

    await tester.scrollUntilVisible(
      find.textContaining('#A3F91C'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('#A3F91C'), findsOneWidget);
    expect(find.textContaining('Gizli Sporcu'), findsNothing);
  });

  testWidgets(
      'SharedFinanceLedgerScreen renders paginated masked entries, clears state on club change, and passes 320px/2.0x layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const clubId = 'club-acc-1';
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
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
            ClubRef(id: 'club-acc-2', name: 'Boğaziçi SK', role: 'accountant'),
          ],
        ),
        clubLedgerPageProvider.overrideWith((ref, offset) async {
          final selected =
              ref.watch(selectedAccountantClubIdProvider) ?? clubId;
          if (selected == 'club-acc-2') {
            return LedgerPage(
              entries: [
                LedgerEntry(
                  id: 'entry-b1',
                  movedOn: DateTime.utc(2026, 10, 20),
                  direction: 'in',
                  label: 'Boğaziçi Aidat Tahsilatı',
                  category: 'Aidat',
                  counterpart: '#B8821D',
                  account: 'Boğaziçi Banka',
                  amount: 4200,
                  status: 'complete',
                ),
              ],
              totalCount: 1,
            );
          }
          return LedgerPage(
            entries: [
              LedgerEntry(
                id: 'entry-a1',
                movedOn: DateTime.utc(2026, 10, 19),
                direction: 'in',
                label: 'Anadolu Aidat Tahsilatı',
                category: 'Aidat',
                counterpart: '#A3F91C',
                account: 'Anadolu Banka',
                amount: 2500,
                status: 'complete',
              ),
            ],
            totalCount: 65,
          );
        }),
      ],
    );
    addTearDown(container.dispose);

    container.read(proPendingOperationsProvider.notifier).saveOperation(
      scopeKey: 'u1:accounting:club-acc-1:draft',
      operationId: 'op-1',
      payload: const {'p_amount': 500},
    );

    await tester.pumpWidget(
      _buildHost(
        container: container,
        textScaleFactor: 2.0,
        child: const SharedFinanceLedgerScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.textContaining('Anadolu Aidat Tahsilatı'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Anadolu Aidat Tahsilatı'), findsOneWidget);
    expect(
      find.textContaining('Karşı Taraf / Referans: #A3F91C'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('ledger-next-page-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    final nextBtn = find.byKey(const Key('ledger-next-page-button'));
    expect(nextBtn, findsOneWidget);
    expect(tester.getSize(nextBtn).height, greaterThanOrEqualTo(48));

    // Scroll back to top and switch club via selector:
    await tester.scrollUntilVisible(
      find.byKey(const Key('accountant-club-selector')),
      -120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('accountant-club-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Boğaziçi SK').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(selectedAccountantClubIdProvider), 'club-acc-2');
    expect(
      container
          .read(proPendingOperationsProvider)
          .operationFor('u1:accounting:club-acc-1:draft'),
      isNull,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Boğaziçi Aidat Tahsilatı'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Anadolu Aidat Tahsilatı'), findsNothing);
    expect(
      find.textContaining('Karşı Taraf / Referans: #A3F91C'),
      findsNothing,
    );
    expect(find.textContaining('Boğaziçi Aidat Tahsilatı'), findsOneWidget);
    expect(
      find.textContaining('Karşı Taraf / Referans: #B8821D'),
      findsOneWidget,
    );
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
