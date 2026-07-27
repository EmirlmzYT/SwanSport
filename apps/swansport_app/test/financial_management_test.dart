import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/financial_management/application/financial_controller.dart';
import 'package:swansport_app/features/financial_management/domain/financial_management.dart';
import 'package:swansport_app/features/financial_management/presentation/financial_management_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  test(
      'financial domain filters, permissions, and debt aging work deterministically',
      () {
    final repo = FixtureFinancialRepository();
    final inv = repo.invoices.first;
    expect(inv.documentNo, 'INV-2026-001');
    expect(const FinancialFilter(query: 'Mehmet').matchesInvoice(inv), isTrue);
    expect(const FinancialFilter(query: 'Ahmet').matchesInvoice(inv), isFalse);

    // Financial permissions check
    expect(
      permissionsForFinancialRole(FinancialRole.financialManager)
          .canApproveExpenses,
      isTrue,
    );
    expect(
      permissionsForFinancialRole(FinancialRole.coach).canApproveExpenses,
      isFalse,
    );
    expect(
      permissionsForFinancialRole(FinancialRole.parent).canApproveExpenses,
      isFalse,
    );

    // Debt aging category check
    final debt = repo.debts.first;
    expect(debt.agingCategory, '31-60 Gün');

    // Metrics check
    final metrics = repo.metrics;
    expect(metrics.totalExpectedRevenue, 8000.0);
    expect(metrics.totalCollectedRevenue, 4000.0);
    expect(metrics.collectionRate, 50);
  });

  testWidgets(
      'financial management renders responsively across sizes and dark/light modes',
      (t) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final w in mode == ThemeMode.light
          ? [375.0, 600.0, 768.0, 1024.0, 1440.0]
          : [375.0, 1024.0]) {
        t.view.physicalSize = Size(w, 1000);
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: SwanTheme.light(),
              darkTheme: SwanTheme.dark(),
              themeMode: mode,
              home: const FinancialManagementScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('financial management search and detail navigation work',
      (t) async {
    t.view.physicalSize = const Size(900, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();

    final nav = t.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/financial-management'));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('financial-command-center')), findsOneWidget);

    await t.enterText(
      find.byKey(const Key('financial-search')),
      'INV-2026-001',
    );
    await t.pump();

    await t.tap(find.byKey(const Key('invoice-inv_101')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('financial-detail-docno')), findsOneWidget);
  });

  test('payment, installment, budget and cash-flow calculations are correct',
      () {
    final repo = FixtureFinancialRepository();
    final fee = repo.feeProfiles.first;
    expect(fee.netAmount, 2700);
    expect(repo.installmentPlans.first.remainingAmount, 6000);
    expect(repo.installmentPlans.first.completionPercentage, 50);
    expect(repo.budgets.first.variance, -38000);
    expect(repo.budgets.first.remaining, 38000);
    expect(repo.budgets.last.exceeded, isTrue);
    expect(repo.cashFlow.last.net, 21000);
    expect(repo.cashFlow.last.forecast, 24500);
    expect(repo.invoices.last.dueDate.isBefore(DateTime(2026, 7, 24)), isTrue);
  });

  test('provider exposes operations and permission-aware demo exports', () {
    final controller = FinancialController(FixtureFinancialRepository());
    expect(controller.state.payments, isNotEmpty);
    expect(controller.state.refunds, isNotEmpty);
    expect(controller.state.alerts, isNotEmpty);
    expect(controller.state.audit, isNotEmpty);

    controller.requestExport(ExportFormat.csv);
    expect(controller.state.exports.single.state, ExportState.demoReady);
    expect(
      controller.state.audit.last.action,
      FinancialAuditAction.export,
    );

    controller.changeRole(FinancialRole.parent);
    expect(controller.state.filteredInvoices, hasLength(1));
    expect(controller.state.filteredInvoices.single.athleteName, 'Arda Yılmaz');
    expect(controller.state.canViewOperations, isFalse);

    controller.changeRole(FinancialRole.coach);
    expect(controller.state.canViewPayerIdentity, isFalse);

    controller.changeRole(FinancialRole.medicalStaff);
    expect(controller.state.hasFinancialAccess, isFalse);
    controller.requestExport(ExportFormat.pdf);
    expect(controller.state.exports, hasLength(1));
  });

  testWidgets('financial dashboard exposes operational and accessible surfaces',
      (t) async {
    t.view.physicalSize = const Size(1024, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const FinancialManagementScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('financial-kpi-grid')), findsOneWidget);
    expect(find.byKey(const Key('financial-fees')), findsOneWidget);
    expect(find.byKey(const Key('financial-budget')), findsOneWidget);
    expect(find.byKey(const Key('financial-cash-flow')), findsOneWidget);
    expect(find.byKey(const Key('financial-audit')), findsOneWidget);
    expect(find.byKey(const Key('financial-export-center')), findsOneWidget);

    await t.tap(find.byKey(const Key('financial-export-csv')));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
