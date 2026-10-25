import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/widgets/console_detail_panel.dart';
import 'package:swansport_console/app/widgets/console_table.dart';

void main() {
  testWidgets('row opens with keyboard and closing preserves list query',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: _TableHarness())));
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    Focus.of(tester.element(find.text('Ada Lovelace'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Dosya içeriği'), findsOneWidget);
    final panel = tester.getSize(find
        .ancestor(
            of: find.text('Dosya içeriği'), matching: find.byType(Material))
        .first);
    expect(panel.width, lessThanOrEqualTo(640));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Dosya içeriği'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Ada');
    expect(find.text('Ada Lovelace'), findsOneWidget);
    await tester.tap(find.text('Filtreleri sıfırla'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(find.text('Dosya içeriği'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export prevents duplicate work and reports failure',
      (tester) async {
    final export = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      return ConsoleToolbar(
          query: const ConsoleTableQuery(search: 'Ada'),
          onQueryChanged: (_) {},
          onExport: () {
            calls++;
            return export.future;
          });
    }))));
    await tester.tap(find.text('CSV'));
    await tester.pump();
    expect(find.text('Hazırlanıyor…'), findsOneWidget);
    await tester.tap(find.text('Hazırlanıyor…'));
    expect(calls, 1);
    export.completeError(StateError('network'));
    await tester.pump();
    expect(find.text('Dışa aktarılamadı. Tekrar deneyin.'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
  });
}

class _TableHarness extends StatefulWidget {
  const _TableHarness();
  @override
  State<_TableHarness> createState() => _TableHarnessState();
}

class _TableHarnessState extends State<_TableHarness> {
  ConsoleTableQuery query = const ConsoleTableQuery();
  @override
  Widget build(BuildContext context) => Column(children: [
        ConsoleToolbar(
            query: query,
            onQueryChanged: (v) => setState(() => query = v),
            onResetFilters: query.search.isEmpty
                ? null
                : () => setState(() => query = const ConsoleTableQuery())),
        Expanded(
            child: ConsoleTable<String>(
          columns: [ConsoleColumn(label: 'Ad', cell: (v) => Text(v))],
          rows: const ['Ada Lovelace'],
          rowId: (v) => v,
          query: query,
          totalCount: 1,
          onQueryChanged: (v) => setState(() => query = v),
          onRowTap: (_) => showConsoleDetailPanel<void>(context,
              title: 'Sporcu', child: const Text('Dosya içeriği')),
        )),
      ]);
}
