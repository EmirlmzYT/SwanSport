import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/reports/application/reports_controller.dart';
import 'package:swansport_app/features/reports/domain/reports_models.dart';
import 'package:swansport_app/features/reports/presentation/screens/reports_screen.dart';

void main() {
  test('reports domain model and controller filtering work deterministically',
      () {
    final notifier = ReportsNotifier();
    expect(notifier.current.kpis.clubHealthScore, 96);
    expect(notifier.current.templates.length, 5);

    notifier.selectCategory(ReportDomainCategory.executive);
    expect(notifier.current.filteredTemplates.length, 1);
    expect(
      notifier.current.filteredTemplates.first.title,
      contains('Operasyonel Sağlık'),
    );

    notifier.updateSearch('Sakatlık');
    expect(notifier.current.filteredTemplates.isEmpty, isTrue);

    notifier.updateSearch('');
    notifier.selectCategory(null);
    expect(notifier.current.filteredTemplates.length, 5);
    expect(
      notifier.current.metrics.first.state,
      MetricDefinitionState.certified,
    );
    expect(notifier.current.commentary, isNotEmpty);
    expect(notifier.current.decisions, isNotEmpty);
    expect(notifier.current.audit, isNotEmpty);
    notifier.saveView('rep-01', 'Test Görünümü');
    expect(notifier.current.savedViews, hasLength(2));
  });

  testWidgets('typed report detail exposes trust and decision surfaces',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.pushNamed('/reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-report-rep-01')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-detail-title')), findsOneWidget);
    expect(find.text('Temel Metrikler'), findsOneWidget);
    expect(find.text('İnsan Yorumu'), findsOneWidget);
    expect(find.text('Karar Günlüğü'), findsOneWidget);
    expect(find.text('Rapor Denetimi'), findsOneWidget);
  });

  testWidgets('reports screen renders executive hero KPIs and filter chips',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Raporlama &'), findsOneWidget);
    expect(find.text('Karar Destek Merkezi'), findsOneWidget);
    expect(find.text('EXECUTIVE HEALTH SCORE: %96'), findsOneWidget);
    expect(find.text('Anomali & Operasyonel Uyarılar'), findsOneWidget);
    expect(find.text('Kulüp Geneli Operasyonel Sağlık Raporu'), findsOneWidget);
  });
}
