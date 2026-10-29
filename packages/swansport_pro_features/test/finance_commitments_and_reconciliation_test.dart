import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets(
      'self-created expense cannot be approved and approve button is disabled in UI',
      (tester) async {
    final recordedApprovals = <Map<String, Object?>>[];
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
            FeatureFlags.recurringExpenses,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        vendorsProvider.overrideWith((ref) async => const <Vendor>[]),
        recurringExpensesProvider.overrideWith(
          (ref) async => [
            RecurringExpense(
              id: 'rec-own-1',
              clubId: 'club-acc-1',
              title: 'Kendi Girdiğim Kamp Gideri',
              amount: 12500,
              frequency: RecurrenceFrequency.monthly,
              startsOn: DateTime.utc(2026, 10, 1),
              ownerId: 'user-acc-1',
              needsApproval: true,
            ),
          ],
        ),
        upcomingOccurrencesProvider.overrideWith(
          (ref) async => const <RecurringOccurrence>[],
        ),
        pendingApprovalsProvider.overrideWith(
          (ref) async => [
            ExpenseRow(
              id: 'exp-own-1',
              amount: 12500,
              spentOn: DateTime.utc(2026, 10, 20),
              status: 'complete',
              categoryName: 'Kamp & Konaklama',
              accountName: 'Ana Banka',
              supplier: 'Anadolu Turizm',
              note: 'Kendi Girdiğim Kamp Gideri',
            ),
            ExpenseRow(
              id: 'exp-other-2',
              amount: 8400,
              spentOn: DateTime.utc(2026, 10, 21),
              status: 'complete',
              categoryName: 'Malzeme',
              accountName: 'Ana Banka',
              supplier: 'Spor Market A.Ş.',
              note: 'Antrenman topu alımı',
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: SharedFinanceCommitmentsScreen(
          writeCallbacks: FinanceCommitmentsWriteCallbacks(
            onDecideApproval: ({
              required clubId,
              required operationId,
              required expenseId,
              required approve,
              reason,
            }) async {
              recordedApprovals.add({
                'clubId': clubId,
                'operationId': operationId,
                'expenseId': expenseId,
                'approve': approve,
              });
              return 'approved';
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Kendi oluşturduğun gideri onaylayamazsın'),
      findsOneWidget,
    );

    final ownApproveButton = tester.widget<FilledButton>(
      find.byKey(const Key('approve-expense-btn-exp-own-1')),
    );
    final ownRejectButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('reject-expense-btn-exp-own-1')),
    );
    expect(ownApproveButton.onPressed, isNull);
    expect(ownRejectButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('approve-expense-btn-exp-own-1')));
    await tester.pumpAndSettle();
    expect(recordedApprovals, isEmpty);

    final otherApproveButton = tester.widget<FilledButton>(
      find.byKey(const Key('approve-expense-btn-exp-other-2')),
    );
    expect(otherApproveButton.onPressed, isNotNull);
  });

  testWidgets(
      'uncertain network failure reuses exact same operationId and payload on retry',
      (tester) async {
    final attempts = <Map<String, Object?>>[];
    var shouldFailWithTimeout = true;

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
            FeatureFlags.recurringExpenses,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        vendorsProvider.overrideWith((ref) async => const <Vendor>[]),
        recurringExpensesProvider.overrideWith(
          (ref) async => const <RecurringExpense>[],
        ),
        upcomingOccurrencesProvider.overrideWith(
          (ref) async => [
            RecurringOccurrence(
              id: 'occ-101',
              recurringId: 'rec-1',
              dueOn: DateTime.utc(2026, 10, 29),
              amount: 15000,
              status: 'pending',
              title: 'Ekim Saha Kirası',
            ),
          ],
        ),
        pendingApprovalsProvider.overrideWith(
          (ref) async => const <ExpenseRow>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: SharedFinanceCommitmentsScreen(
          writeCallbacks: FinanceCommitmentsWriteCallbacks(
            onRecordOccurrence: ({
              required clubId,
              required operationId,
              required occurrenceId,
              required amount,
            }) async {
              attempts.add({
                'clubId': clubId,
                'operationId': operationId,
                'occurrenceId': occurrenceId,
                'amount': amount,
              });
              if (shouldFailWithTimeout) {
                throw TimeoutException('Uncertain network timeout');
              }
              return 'exp-created-1';
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record-occurrence-btn-occ-101')));
    await tester.pumpAndSettle();

    expect(attempts, hasLength(1));
    final firstOpId = attempts.first['operationId'] as String;
    expect(firstOpId, isNotEmpty);

    const scopeKey = 'club-acc-1:occurrence:occ-101';
    final pendingRecord =
        container.read(proPendingOperationsProvider).operationFor(scopeKey);
    expect(pendingRecord, isNotNull);
    expect(pendingRecord!.operationId, firstOpId);
    expect(pendingRecord.payload['occurrenceId'], 'occ-101');
    expect(pendingRecord.payload['amount'], 15000);
    expect(
      container.read(proDirtyStateCoordinatorProvider).hasPendingOperation,
      isTrue,
    );

    shouldFailWithTimeout = false;
    final retryFinder = find.byKey(const Key('retry-pending-op-btn'));
    expect(retryFinder, findsOneWidget);
    await tester.tap(retryFinder);
    await tester.pumpAndSettle();

    expect(attempts, hasLength(2));
    expect(attempts[1]['operationId'], firstOpId);
    expect(attempts[1]['occurrenceId'], attempts[0]['occurrenceId']);
    expect(attempts[1]['amount'], attempts[0]['amount']);
    expect(
      container.read(proPendingOperationsProvider).operationFor(scopeKey),
      isNull,
    );
    expect(
      container.read(proDirtyStateCoordinatorProvider).hasPendingOperation,
      isFalse,
    );
  });

  testWidgets(
      'vendor_private fields (tax ID, tax office, IBAN) are never queried or shown in commitments screen',
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
            FeatureFlags.recurringExpenses,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        vendorsProvider.overrideWith(
          (ref) async => const [
            Vendor(
              id: 'ven-1',
              clubId: 'club-acc-1',
              name: 'Marmara Tesis Bakım Ltd.',
              contactNote: 'Kurumsal İletişim · Dahili 104',
              defaultCategoryName: 'Tesis Bakım',
              expenseCount: 4,
              expenseTotal: 48000,
            ),
          ],
        ),
        recurringExpensesProvider.overrideWith(
          (ref) async => const <RecurringExpense>[],
        ),
        upcomingOccurrencesProvider.overrideWith(
          (ref) async => const <RecurringOccurrence>[],
        ),
        pendingApprovalsProvider.overrideWith(
          (ref) async => const <ExpenseRow>[],
        ),
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
        child: const SharedFinanceCommitmentsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(athleteCalls, 0);
    expect(find.text('Marmara Tesis Bakım Ltd.'), findsOneWidget);
    expect(find.textContaining('Kategori: Tesis Bakım'), findsOneWidget);
    expect(find.textContaining('TR00'), findsNothing);
    expect(find.textContaining('Vergi No:'), findsNothing);
    expect(find.textContaining('Vergi Dairesi:'), findsNothing);
  });

  testWidgets(
      'rejects out-of-scope write when active accountant club scope is lost before execution',
      (tester) async {
    final writeCalls = <String>[];
    final accessState = StateProvider<SwanAccess>(
      (ref) => const SwanAccess(
        isPlatformAdmin: false,
        clubRole: null,
        coachLevel: 0,
        athleteKind: null,
        accountantClubIds: {'club-acc-1'},
      ),
    );

    final container = ProviderContainer(
      overrides: [
        swanAccessProvider.overrideWith((ref) => ref.watch(accessState)),
        featureFlagsProvider.overrideWith(
          (ref) async => const FeatureFlags({
            FeatureFlags.financeOperationsCenter,
            FeatureFlags.bankReconciliation,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        bankImportsProvider.overrideWith(
          (ref) async => [
            BankImport(
              id: 'imp-1',
              accountId: 'acc-1',
              accountName: 'Ana Banka',
              rowCount: 12,
              createdAt: DateTime.utc(2026, 10, 25),
            ),
          ],
        ),
        bankTransactionsProvider.overrideWith(
          (ref, status) async => [
            BankTransaction(
              id: 'txn-1',
              txnOn: DateTime.utc(2026, 10, 25),
              amount: 3200,
              direction: 'in',
              matchStatus: 'unmatched',
              description: 'EFT AIDAT REF #A3F91C ****1234',
              accountName: 'Ana Banka',
            ),
          ],
        ),
        bankMatchSuggestionsProvider.overrideWith(
          (ref, txnId) async => [
            BankMatchSuggestion(
              kind: 'payment',
              entryId: 'pay-1',
              entryOn: DateTime.utc(2026, 10, 25),
              amount: 3200,
              label: 'Aidat Tahakkuku · Referans #A3F91C',
              dayGap: 0,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: SharedBankReconciliationScreen(
          writeCallbacks: BankReconciliationWriteCallbacks(
            onDecideMatch: ({
              required clubId,
              required operationId,
              required txnId,
              required action,
              kind,
              entryId,
              note,
            }) async {
              writeCalls.add('$clubId:$txnId:$action');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Mutate selectedAccountantClubIdProvider to an unauthorized club before tapping match
    container.read(selectedAccountantClubIdProvider.notifier).state =
        'club-unauthorized';

    await tester.tap(find.byKey(const Key('bank-match-btn-txn-1-pay-1')));
    await tester.pump();

    expect(writeCalls, isEmpty);
    expect(
      find.textContaining('Aktif kulüp kapsamı doğrulaması başarısız'),
      findsOneWidget,
    );
  });

  testWidgets(
      'switching club clears pending operations and never carries pending state across clubs',
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
            FeatureFlags.bankReconciliation,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
            ClubRef(id: 'club-acc-2', name: 'Boğaziçi SK', role: 'accountant'),
          ],
        ),
        bankImportsProvider.overrideWith((ref) async => const <BankImport>[]),
        bankTransactionsProvider.overrideWith(
          (ref, status) async => [
            BankTransaction(
              id: 'txn-99',
              txnOn: DateTime.utc(2026, 10, 26),
              amount: 4500,
              direction: 'in',
              matchStatus: 'unmatched',
              description: 'AIDAT #B7C20E',
              accountName: 'Ana Banka',
            ),
          ],
        ),
        bankMatchSuggestionsProvider.overrideWith(
          (ref, txnId) async => const <BankMatchSuggestion>[],
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildHost(
        container: container,
        child: SharedBankReconciliationScreen(
          writeCallbacks: BankReconciliationWriteCallbacks(
            onDecideMatch: ({
              required clubId,
              required operationId,
              required txnId,
              required action,
              kind,
              entryId,
              note,
            }) async {
              throw TimeoutException('Network timeout');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bank-ignore-btn-txn-99')));
    await tester.pumpAndSettle();

    const scopeKey = 'club-acc-1:bank_match:txn-99';
    expect(
      container.read(proPendingOperationsProvider).operationFor(scopeKey),
      isNotNull,
    );
    expect(find.byKey(const Key('retry-pending-op-btn')), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountant-club-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Boğaziçi SK').last);
    await tester.pumpAndSettle();

    expect(container.read(selectedAccountantClubIdProvider), 'club-acc-2');
    expect(
      container.read(proPendingOperationsProvider).operationFor(scopeKey),
      isNull,
    );
    expect(find.byKey(const Key('retry-pending-op-btn')), findsNothing);
  });

  testWidgets(
      'bank reconciliation masks athlete references, fails closed when flag disabled, and fits 320px at 2.0x text scale with >=48dp targets',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
            FeatureFlags.financeOperationsCenter,
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
        child: const SharedBankReconciliationScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('kademeli yayında'), findsOneWidget);

    final activeContainer = ProviderContainer(
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
            FeatureFlags.bankReconciliation,
          }),
        ),
        myClubsProvider.overrideWith(
          (ref) async => const [
            ClubRef(id: 'club-acc-1', name: 'Anadolu SK', role: 'accountant'),
          ],
        ),
        bankImportsProvider.overrideWith((ref) async => const <BankImport>[]),
        bankTransactionsProvider.overrideWith(
          (ref, status) async => [
            BankTransaction(
              id: 'txn-320',
              txnOn: DateTime.utc(2026, 10, 26),
              amount: 2750,
              direction: 'in',
              matchStatus: 'unmatched',
              description: 'HAVALE AIDAT #C9D14A ****9876',
              accountName: 'Ana Banka',
            ),
          ],
        ),
        bankMatchSuggestionsProvider.overrideWith(
          (ref, txnId) async => [
            BankMatchSuggestion(
              kind: 'payment',
              entryId: 'pay-320',
              entryOn: DateTime.utc(2026, 10, 26),
              amount: 2750,
              label: 'Aidat #C9D14A',
              dayGap: 0,
            ),
          ],
        ),
      ],
    );
    addTearDown(activeContainer.dispose);

    await tester.pumpWidget(
      KeyedSubtree(
        key: UniqueKey(),
        child: _buildHost(
          container: activeContainer,
          textScaleFactor: 2.0,
          child: const SharedBankReconciliationScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.textContaining('HAVALE AIDAT #C9D14A'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('#C9D14A'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('bank-match-btn-txn-320-pay-320')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    final matchBtnSize = tester.getSize(
      find.byKey(const Key('bank-match-btn-txn-320-pay-320')),
    );
    expect(matchBtnSize.height, greaterThanOrEqualTo(48));
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
