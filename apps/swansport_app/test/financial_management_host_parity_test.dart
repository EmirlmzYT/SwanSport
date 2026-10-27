import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/financial_management/presentation/accountant_privacy_ledger_screen.dart';
import 'package:swansport_app/features/financial_management/presentation/closed_period_reversal_screen.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  testWidgets(
      'AccountantPrivacyLedgerScreen acts as thin host wrapper around SharedFinanceLedgerScreen',
      (tester) async {
    const club =
        ClubRef(id: 'club-parity-1', name: 'Parity SK', role: 'accountant');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(false),
          activeClubProvider.overrideWith((ref) async => club),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'accountant',
              coachLevel: 0,
              athleteKind: null,
              accountantClubIds: {'club-parity-1'},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.financeOperationsCenter,
            }),
          ),
          myClubsProvider.overrideWith((ref) async => const [club]),
          clubLedgerPageProvider(0).overrideWith(
            (ref) async => LedgerPage(
              entries: [
                LedgerEntry(
                  id: 'entry-parity-1',
                  movedOn: DateTime.utc(2026, 10, 27, 10),
                  direction: 'in',
                  label: 'Ekim Aidatı',
                  category: 'Aidat',
                  counterpart: '#REF-8842',
                  account: 'Banka',
                  amount: 1500,
                  status: 'confirmed',
                ),
              ],
              totalCount: 1,
            ),
          ),
        ],
        child: const MaterialApp(
          home: AccountantPrivacyLedgerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SharedFinanceLedgerScreen), findsOneWidget);
    expect(find.textContaining('#REF-8842'), findsOneWidget);
    expect(find.text('1 kayıt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ClosedPeriodReversalScreen acts as thin host wrapper around SharedPeriodClosingScreen',
      (tester) async {
    const club =
        ClubRef(id: 'club-parity-1', name: 'Parity SK', role: 'accountant');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(false),
          activeClubProvider.overrideWith((ref) async => club),
          swanAccessProvider.overrideWithValue(
            const SwanAccess(
              isPlatformAdmin: false,
              clubRole: 'accountant',
              coachLevel: 0,
              athleteKind: null,
              accountantClubIds: {'club-parity-1'},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.financeOperationsCenter,
              FeatureFlags.periodClosing,
            }),
          ),
          myClubsProvider.overrideWith((ref) async => const [club]),
          financePeriodsProvider.overrideWith(
            (ref) async => [
              FinancePeriod(
                id: 'period-parity-1',
                clubId: 'club-parity-1',
                periodFrom: DateTime.utc(2026, 9, 1),
                periodTo: DateTime.utc(2026, 9, 30),
                status: 'closed',
              ),
            ],
          ),
          financeAdjustmentsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: ClosedPeriodReversalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SharedPeriodClosingScreen), findsOneWidget);
    expect(find.text('Yeni Ters İşlem'), findsOneWidget);
    expect(
      find.textContaining(
        'Kapalı dönem kayıtları doğrudan düzenlenemez veya silinemez',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
