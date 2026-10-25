import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/features/finance/expense_dialog.dart';
import 'package:swansport_console/features/finance/ledger_providers.dart';
import 'package:swansport_console/features/schedule/series_dialog.dart';
import 'package:swansport_data/swansport_data.dart';

class _Expenses extends Fake implements ExpenseService {
  int calls = 0;
  num? amount;
  String? note;
  final result = Completer<String>();
  @override
  Future<String> addExpense(
      {required String clubId,
      required num amount,
      required DateTime spentOn,
      String? categoryId,
      String? accountId,
      String? supplier,
      String? note,
      String? receiptPath}) {
    calls++;
    this.amount = amount;
    this.note = note;
    return result.future;
  }
}

class _ClubOps extends Fake implements ClubOpsService {
  int calls = 0;
  @override
  Future<int> createEventSeries(
      {required String clubId,
      required String title,
      required String kind,
      required DateTime from,
      required DateTime until,
      required int hour,
      required int minute,
      required List<int> weekdays,
      int minutes = 90,
      String? facilityId,
      String? place}) async {
    calls++;
    return 12;
  }
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> open(WidgetTester tester,
      {required _Expenses expenses, _ClubOps? ops, bool series = false}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          expenseServiceProvider.overrideWithValue(expenses),
          if (ops != null) clubOpsServiceProvider.overrideWithValue(ops),
          activeClubProvider.overrideWith(
              (_) async => const ClubRef(id: 'club', name: 'Test kulübü')),
          expenseCategoriesProvider.overrideWith((_) async => const []),
          cashAccountsProvider.overrideWith((_) async => const []),
          supplierSuggestionsProvider.overrideWith((_) async => const []),
          facilitiesProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp(
            theme: ConsoleTheme.light(),
            home: Scaffold(
              body: Consumer(
                  builder: (context, ref, _) => TextButton(
                      onPressed: () => series
                          ? showSeriesDialog(context, ref)
                          : showExpenseDialog(context, ref),
                      child: const Text('Aç'))),
            ))));
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'expense shows essentials, validates inline and retains optional input after failure',
      (tester) async {
    final service = _Expenses();
    await open(tester, expenses: service);
    expect(find.text('Ek bilgiler'), findsOneWidget);
    expect(find.byKey(const Key('expense_note')), findsNothing);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.text('Sıfırdan büyük bir tutar gir.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expense_amount')), '1.250,50');
    await tester.tap(find.text('Ek bilgiler'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('expense_note')), 'Sezon malzemesi');
    await tester.tap(find.text('Ek bilgiler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(service.calls, 1);
    expect(service.amount, 1250.5);
    expect(service.note, 'Sezon malzemesi');
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    service.result.completeError(StateError('Sunucuya ulaşılamadı'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
    await tester.tap(find.text('Ek bilgiler'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('expense_note')))
            .controller!
            .text,
        'Sezon malzemesi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense blocks duplicate submissions and reports success',
      (tester) async {
    final service = _Expenses();
    await open(tester, expenses: service);
    await tester.enterText(find.byKey(const Key('expense_amount')), '250');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(service.calls, 1);
    final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kaydediliyor…'));
    expect(save.onPressed, isNull);
    service.result.complete('expense-id');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Gider kaydedildi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'series invalid duration never falls back silently to a previous value',
      (tester) async {
    final ops = _ClubOps();
    await open(tester, expenses: _Expenses(), ops: ops, series: true);
    await tester.enterText(find.byKey(const Key('series_duration')), 'abc');
    await tester.tap(find.text('Oluştur'));
    await tester.pumpAndSettle();
    expect(ops.calls, 0);
    expect(find.text('Sıfırdan büyük bir dakika değeri gir.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('series_duration')), '60');
    await tester.tap(find.text('Oluştur'));
    await tester.pumpAndSettle();
    expect(ops.calls, 1);
    expect(find.text('12 antrenman oluşturuldu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
