import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  test('context key equality includes user, workspace, club, and scope', () {
    const original = ProFeatureContextKey(
      userId: 'user-1',
      workspace: 'club',
      clubId: 'club-1',
      scopeId: 'fed-1:futbol:34',
    );

    expect(
      original,
      const ProFeatureContextKey(
        userId: 'user-1',
        workspace: 'club',
        clubId: 'club-1',
        scopeId: 'fed-1:futbol:34',
      ),
    );
    expect(
      original,
      isNot(
        const ProFeatureContextKey(
          userId: 'user-2',
          workspace: 'club',
          clubId: 'club-1',
          scopeId: 'fed-1:futbol:34',
        ),
      ),
    );
    expect(
      original,
      isNot(
        const ProFeatureContextKey(
          userId: 'user-1',
          workspace: 'coaching',
          clubId: 'club-1',
          scopeId: 'fed-1:futbol:34',
        ),
      ),
    );
    expect(
      original,
      isNot(
        const ProFeatureContextKey(
          userId: 'user-1',
          workspace: 'club',
          clubId: 'club-2',
          scopeId: 'fed-1:futbol:34',
        ),
      ),
    );
    expect(
      original,
      isNot(
        const ProFeatureContextKey(
          userId: 'user-1',
          workspace: 'club',
          clubId: 'club-1',
          scopeId: 'fed-2:basketbol:06',
        ),
      ),
    );
  });

  test(
      'phase 4 context key factories isolate accounting, facility, and platform scopes',
      () {
    const accountingA = ProFeatureContextKey.accounting(
      userId: 'user-1',
      accountingClubId: 'acc-club-1',
    );
    const accountingB = ProFeatureContextKey.accounting(
      userId: 'user-1',
      accountingClubId: 'acc-club-2',
    );
    const facilityA = ProFeatureContextKey.facility(
      userId: 'user-1',
      facilityScopeId: 'turf-field-1',
      clubId: 'club-1',
    );
    const facilityB = ProFeatureContextKey.facility(
      userId: 'user-1',
      facilityScopeId: 'turf-field-2',
      clubId: 'club-1',
    );
    const platform = ProFeatureContextKey.platform(userId: 'user-1');

    expect(accountingA.workspace, 'accounting');
    expect(accountingA.accountingClubId, 'acc-club-1');
    expect(accountingA, isNot(accountingB));

    expect(facilityA.workspace, 'facility');
    expect(facilityA.facilityScopeId, 'turf-field-1');
    expect(facilityA, isNot(facilityB));

    expect(platform.workspace, 'platform');
    expect(platform.clubId, isNull);
    expect(platform.scopeId, 'platform');
    expect(platform, isNot(accountingA));
    expect(platform, isNot(facilityA));
  });

  test('context invalidation targets are explicit and unique', () {
    expect(proFeatureInvalidationTargets, contains('selectedClubIdProvider'));
    expect(proFeatureInvalidationTargets, contains('teamRosterProvider'));
    expect(proFeatureInvalidationTargets, contains('attendanceQueueProvider'));
    expect(proFeatureInvalidationTargets, contains('trainingSessionProvider'));
    expect(
      proFeatureInvalidationTargets,
      contains('selectedFederationScopeKeyProvider'),
    );
    expect(
      proFeatureInvalidationTargets,
      contains('federationConsoleScopesProvider'),
    );
    expect(
      proFeatureInvalidationTargets,
      contains('federationConsoleMatchesProvider'),
    );
    expect(
      proFeatureInvalidationTargets,
      contains('federationDisciplinaryReportsProvider'),
    );
    expect(
      proFeatureInvalidationTargets,
      contains('myRefereeMatchesProvider'),
    );
    expect(
      proFeatureInvalidationTargets,
      contains('refereeLineupCandidatesProvider'),
    );
    expect(
      proFeatureInvalidationTargets,
      contains('refereeMatchStateProvider'),
    );
    expect(
      proFeatureInvalidationTargets,
      contains('refereeReportDraftsProvider'),
    );
    // Phase 4 scoped targets:
    expect(
      proFeatureInvalidationTargets,
      containsAll(<String>[
        'selectedAccountantClubIdProvider',
        'myAccountantClubIdsProvider',
        'financeOperationsSummaryProvider',
        'clubLedgerPageProvider',
        'cashAccountsProvider',
        'accountBalancesProvider',
        'expenseCategoriesProvider',
        'receivablesProvider',
        'vendorsProvider',
        'recurringExpensesProvider',
        'upcomingOccurrencesProvider',
        'approvalPoliciesProvider',
        'pendingApprovalsProvider',
        'bankImportsProvider',
        'bankTransactionsProvider',
        'bankMatchSuggestionsProvider',
        'budgetLinesProvider',
        'cashForecastProvider',
        'financePeriodsProvider',
        'financeAdjustmentsProvider',
        'candidateAdjustableEntriesProvider',
        'closedPeriodCandidatesPageProvider',
        'selectedFacilityScopeIdProvider',
        'myManagedTurfFieldIdsProvider',
        'delegatedTurfFieldIdsProvider',
        'turfFieldsProvider',
        'turfOccupancyGridProvider',
        'turfDutiesProvider',
        'facilitiesProvider',
        'facilityLoadProvider',
        'facilityScheduleProvider',
        'facilityReservationsProvider',
        'myClubOperationsAuthorityProvider',
        'clubInventoryBoardProvider',
        'clubHealthOperationsProvider',
        'clubSportingOverviewProvider',
        'clubOperationControllerProvider',
        'reportAthletesProvider',
        'developmentReportProvider',
        'platformConfigProvider',
        'platformPlansProvider',
        'platformAuditLogsProvider',
        'launchWaitlistSummaryProvider',
        'launchWaitlistEntriesProvider',
        'proPendingOperationsProvider',
      ]),
    );
    expect(
      proFeatureInvalidationTargets,
      isNot(contains('eligibilityProvider')),
    );
    expect(
      proFeatureInvalidationTargets,
      isNot(contains('eligibilityBoardProvider')),
    );
    expect(
      proFeatureInvalidationTargets.toSet(),
      hasLength(proFeatureInvalidationTargets.length),
    );
  });

  test(
      'phase 4 scope selectors and pending operations isolate by scope and clear on reset',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(selectedAccountantClubIdProvider.notifier).state =
        'acc-club-1';
    container.read(selectedFacilityScopeIdProvider.notifier).state =
        'turf-field-1';
    container.read(proPendingOperationsProvider.notifier).saveOperation(
      scopeKey: 'user-1:accounting:acc-club-1:draft_expense',
      operationId: 'op-123',
      payload: const {'p_amount': 1500},
    );

    expect(container.read(selectedAccountantClubIdProvider), 'acc-club-1');
    expect(container.read(selectedFacilityScopeIdProvider), 'turf-field-1');
    expect(
      container
          .read(proPendingOperationsProvider)
          .operationFor('user-1:accounting:acc-club-1:draft_expense')
          ?.operationId,
      'op-123',
    );
    expect(
      container
          .read(proPendingOperationsProvider)
          .operationFor('user-2:accounting:acc-club-1:draft_expense'),
      isNull,
    );

    container
      ..invalidate(selectedAccountantClubIdProvider)
      ..invalidate(selectedFacilityScopeIdProvider)
      ..invalidate(proPendingOperationsProvider);

    expect(container.read(selectedAccountantClubIdProvider), isNull);
    expect(container.read(selectedFacilityScopeIdProvider), isNull);
    expect(
      container
          .read(proPendingOperationsProvider)
          .operationFor('user-1:accounting:acc-club-1:draft_expense'),
      isNull,
    );
  });

  test(
      'referee report draft isolates by userId and matchId and clears on reset',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(refereeReportDraftsProvider.notifier).saveDraft(
          userId: 'user-1',
          matchId: 'match-a',
          notes: 'Kırmızı kart ve saha olayı notu',
        );

    expect(
      container.read(refereeReportDraftsProvider).draftFor(
            userId: 'user-1',
            matchId: 'match-a',
          ),
      'Kırmızı kart ve saha olayı notu',
    );
    expect(
      container.read(refereeReportDraftsProvider).draftFor(
            userId: 'user-2',
            matchId: 'match-a',
          ),
      isNull,
    );

    container.invalidate(refereeReportDraftsProvider);
    expect(
      container.read(refereeReportDraftsProvider).draftFor(
            userId: 'user-1',
            matchId: 'match-a',
          ),
      isNull,
    );
  });

  testWidgets('context boundary disposes the old keyed subtree',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final disposedContexts = <ProFeatureContextKey?>[];
    const first = ProFeatureContextKey(
      userId: 'user-1',
      workspace: 'club',
      clubId: 'club-1',
    );
    const second = ProFeatureContextKey(
      userId: 'user-1',
      workspace: 'club',
      clubId: 'club-2',
    );
    container.read(proFeatureContextProvider.notifier).state = first;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final featureContext = ref.watch(proFeatureContextProvider);
              return ProFeatureContextBoundary(
                contextKey: featureContext,
                child: _DisposeProbe(
                  contextKey: featureContext,
                  onDispose: disposedContexts.add,
                ),
              );
            },
          ),
        ),
      ),
    );

    container.read(proFeatureContextProvider.notifier).state = second;
    await tester.pump();

    expect(disposedContexts, [first]);
    expect(find.text('club-2'), findsOneWidget);
  });
}

final class _DisposeProbe extends StatefulWidget {
  const _DisposeProbe({required this.contextKey, required this.onDispose});

  final ProFeatureContextKey? contextKey;
  final ValueChanged<ProFeatureContextKey?> onDispose;

  @override
  State<_DisposeProbe> createState() => _DisposeProbeState();
}

final class _DisposeProbeState extends State<_DisposeProbe> {
  @override
  void dispose() {
    widget.onDispose(widget.contextKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(widget.contextKey?.clubId ?? '-');
}
