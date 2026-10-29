import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/app/widgets/console_table.dart';
import 'package:swansport_console/features/finance/ledger_screen.dart';
import 'package:swansport_console/features/finance/ledger_providers.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  final entry = LedgerEntry(
      id: 'income',
      movedOn: DateTime(2026, 10, 25),
      direction: 'in',
      label: 'Aidat kaydı',
      category: 'Aidat',
      counterpart: '#A3F91C',
      account: 'Banka',
      amount: 250,
      status: 'confirmed');
  Future<void> open(WidgetTester tester,
      {Completer<LedgerTotals>? totals}) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          consoleAccessProvider.overrideWithValue(const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null,
              accountantClubIds: {'club'})),
          ledgerQueryProvider
              .overrideWith((_) => const ConsoleTableQuery(page: 2)),
          ledgerProvider.overrideWith(
              (_) async => LedgerPage(entries: [entry], totalCount: 101)),
          ledgerTotalsProvider.overrideWith((_) =>
              totals?.future ??
              Future.value(
                  const LedgerTotals(income: 250, outgo: 0, net: 250))),
          draftExpensesProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp(
            theme: ConsoleTheme.light(),
            home: const Scaffold(body: LedgerScreen()))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('income inspection is read only and closing preserves list page',
      (tester) async {
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.text('Aidat kaydı'));
    await tester.pumpAndSettle();
    expect(find.text('İşlem ayrıntısı'), findsOneWidget);
    expect(find.text('#A3F91C').last, findsOneWidget);
    expect(find.text('Gideri düzenle'), findsNothing);
    await tester.tap(find.byTooltip('Ayrıntıyı kapat'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Aidat kaydı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and failed totals never show invented zero balances',
      (tester) async {
    final totals = Completer<LedgerTotals>();
    await open(tester, totals: totals);
    expect(find.text('Toplamlar yükleniyor…'), findsOneWidget);
    totals.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Toplamlar alınamadı.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
