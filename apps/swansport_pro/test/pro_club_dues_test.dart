import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_router.dart';
import 'package:swansport_pro/features/operations/pro_club_dues_screen.dart';

void main() {
  test('club dues route is registered', () {
    expect(ProRoutes.registeredPatterns, contains(ProRoutes.clubDues));
  });

  testWidgets('club admin sees real partial and pending finance states',
      (tester) async {
    final overview = ClubDuesOverview(
      summary: const ClubDuesSummary(
        billed: 1000,
        collected: 400,
        outstanding: 600,
        paidCount: 0,
        partialCount: 1,
        pendingCount: 0,
        overdueCount: 1,
        pendingPaymentCount: 1,
      ),
      invoices: [
        ClubDueInvoice(
          id: 'invoice',
          athleteId: 'athlete',
          athleteName: 'Ada Yılmaz',
          label: 'Kasım aidatı',
          amount: 1000,
          confirmedAmount: 400,
          pendingAmount: 200,
          balance: 600,
          status: 'partial',
          period: '2026-11',
          dueDate: DateTime(2026, 11, 10),
        ),
      ],
      periods: const ['2026-11'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club',
              name: 'Kulüp',
              role: 'club_admin',
            ),
          ),
          clubDuesOverviewProvider.overrideWith((ref) async => overview),
        ],
        child: const MaterialApp(home: ProClubDuesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada Yılmaz'), findsOneWidget);
    expect(find.text('Kısmi'), findsOneWidget);
    expect(find.textContaining('Kalan: 600'), findsOneWidget);
    expect(find.text('Tahsilat gir'), findsOneWidget);
  });

  testWidgets('coach fails closed before constructing dues provider',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClubProvider.overrideWith(
            (ref) async => const ClubRef(
              id: 'club',
              name: 'Kulüp',
              role: 'coach',
            ),
          ),
        ],
        child: const MaterialApp(home: ProClubDuesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('kulüp yöneticisi'), findsWidgets);
    expect(find.text('Aidatlar'), findsNothing);
  });
}
