import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_models/swansport_models.dart';
import '../domain/financial_management.dart';

class FinancialCenterState {
  final List<InvoiceRecord> invoices;
  final List<PaymentRecord> payments;
  final List<InstallmentPlan> installmentPlans;
  final List<DebtRecord> debts;
  final List<ExpenseRecord> expenses;
  final List<FinancialAlert> alerts;
  final List<AthleteFeeProfile> feeProfiles;
  final List<RefundRecord> refunds;
  final List<ReceiptRecord> receipts;
  final List<BudgetRecord> budgets;
  final List<CashFlowPoint> cashFlow;
  final List<FinancialAuditEntry> audit;
  final List<FinancialExportRecord> exports;
  final ExecutiveFinancialMetrics metrics;
  final FinancialFilter filter;
  final FinancialRole currentRole;
  final bool loading;

  const FinancialCenterState({
    required this.invoices,
    required this.payments,
    required this.installmentPlans,
    required this.debts,
    required this.expenses,
    required this.alerts,
    required this.feeProfiles,
    required this.refunds,
    required this.receipts,
    required this.budgets,
    required this.cashFlow,
    required this.audit,
    this.exports = const [],
    required this.metrics,
    required this.filter,
    required this.currentRole,
    this.loading = false,
  });

  FinancialPermissions get permissions =>
      permissionsForFinancialRole(currentRole);

  List<InvoiceRecord> get filteredInvoices {
    final scoped = switch (currentRole) {
      FinancialRole.parent ||
      FinancialRole.athlete =>
        invoices.where((i) => i.athleteName == 'Arda Yılmaz'),
      FinancialRole.clubOwner ||
      FinancialRole.medicalStaff =>
        const Iterable<InvoiceRecord>.empty(),
      _ => invoices,
    };
    return scoped.where((i) => filter.matchesInvoice(i)).toList();
  }

  bool get hasFinancialAccess => currentRole != FinancialRole.medicalStaff;

  bool get canViewOperations => switch (currentRole) {
        FinancialRole.financialManager ||
        FinancialRole.accountant ||
        FinancialRole.administrator ||
        FinancialRole.branchManager ||
        FinancialRole.facilityManager ||
        FinancialRole.auditor =>
          true,
        _ => false,
      };

  bool get canViewInvoiceDirectory =>
      currentRole != FinancialRole.clubOwner &&
      currentRole != FinancialRole.medicalStaff;

  bool get canViewPayerIdentity =>
      currentRole != FinancialRole.coach &&
      currentRole != FinancialRole.athlete;

  FinancialCenterState copyWith({
    List<InvoiceRecord>? invoices,
    List<PaymentRecord>? payments,
    List<InstallmentPlan>? installmentPlans,
    List<DebtRecord>? debts,
    List<ExpenseRecord>? expenses,
    List<FinancialAlert>? alerts,
    List<AthleteFeeProfile>? feeProfiles,
    List<RefundRecord>? refunds,
    List<ReceiptRecord>? receipts,
    List<BudgetRecord>? budgets,
    List<CashFlowPoint>? cashFlow,
    List<FinancialAuditEntry>? audit,
    List<FinancialExportRecord>? exports,
    ExecutiveFinancialMetrics? metrics,
    FinancialFilter? filter,
    FinancialRole? currentRole,
    bool? loading,
  }) {
    return FinancialCenterState(
      invoices: invoices ?? this.invoices,
      payments: payments ?? this.payments,
      installmentPlans: installmentPlans ?? this.installmentPlans,
      debts: debts ?? this.debts,
      expenses: expenses ?? this.expenses,
      alerts: alerts ?? this.alerts,
      feeProfiles: feeProfiles ?? this.feeProfiles,
      refunds: refunds ?? this.refunds,
      receipts: receipts ?? this.receipts,
      budgets: budgets ?? this.budgets,
      cashFlow: cashFlow ?? this.cashFlow,
      audit: audit ?? this.audit,
      exports: exports ?? this.exports,
      metrics: metrics ?? this.metrics,
      filter: filter ?? this.filter,
      currentRole: currentRole ?? this.currentRole,
      loading: loading ?? this.loading,
    );
  }
}

class FinancialController extends StateNotifier<FinancialCenterState> {
  final FixtureFinancialRepository _repository;

  FinancialController(this._repository)
      : super(
          FinancialCenterState(
            invoices: _repository.invoices,
            payments: _repository.payments,
            installmentPlans: _repository.installmentPlans,
            debts: _repository.debts,
            expenses: _repository.expenses,
            alerts: _repository.alerts,
            feeProfiles: _repository.feeProfiles,
            refunds: _repository.refunds,
            receipts: _repository.receipts,
            budgets: _repository.budgets,
            cashFlow: _repository.cashFlow,
            audit: _repository.audit,
            metrics: _repository.metrics,
            filter: const FinancialFilter(),
            currentRole: FinancialRole.financialManager,
          ),
        );

  void search(String query) {
    state = state.copyWith(
      filter: FinancialFilter(
        query: query,
        branch: state.filter.branch,
        status: state.filter.status,
        onlyOverdue: state.filter.onlyOverdue,
      ),
    );
  }

  void filterStatus(ChargeStatus? status) {
    state = state.copyWith(
      filter: FinancialFilter(
        query: state.filter.query,
        branch: state.filter.branch,
        status: status,
        onlyOverdue: state.filter.onlyOverdue,
      ),
    );
  }

  void filterOverdueOnly(bool? overdueOnly) {
    state = state.copyWith(
      filter: FinancialFilter(
        query: state.filter.query,
        branch: state.filter.branch,
        status: state.filter.status,
        onlyOverdue: overdueOnly,
      ),
    );
  }

  void changeRole(FinancialRole role) {
    state = state.copyWith(currentRole: role);
  }

  void recordPayment(SwanId invoiceId, double amount, PaymentMethod method) {
    if (!state.permissions.canRecordPayments) return;
    _repository.recordPayment(invoiceId, amount, method);
    state = state.copyWith(
      invoices: _repository.invoices,
      metrics: _repository.metrics,
    );
  }

  void approveExpense(SwanId expenseId) {
    if (!state.permissions.canApproveExpenses) return;
    _repository.approveExpense(expenseId);
    state = state.copyWith(
      expenses: _repository.expenses,
      metrics: _repository.metrics,
    );
  }

  void dismissAlert(SwanId alertId) {
    final updated = state.alerts.where((a) => a.id != alertId).toList();
    state = state.copyWith(alerts: updated);
  }

  void requestExport(ExportFormat format) {
    if (!state.permissions.canViewExecutiveDashboard &&
        !state.permissions.canManageBilling) {
      return;
    }
    final now = DateTime.now();
    final record = FinancialExportRecord(
      id: SwanId('export_${state.exports.length + 1}'),
      format: format,
      state: ExportState.demoReady,
      requestedAt: now,
      requestedBy: state.currentRole.name,
    );
    final auditEntry = FinancialAuditEntry(
      id: SwanId('faudit_export_${state.audit.length + 1}'),
      action: FinancialAuditAction.export,
      actor: state.currentRole.name,
      occurredAt: now,
      entityReference: format.name,
      summary: 'Demo dışa aktarma hazırlandı; gerçek dosya oluşturulmadı.',
    );
    state = state.copyWith(
      exports: [...state.exports, record],
      audit: [...state.audit, auditEntry],
    );
  }
}

final financialRepositoryProvider =
    Provider<FixtureFinancialRepository>((ref) => FixtureFinancialRepository());

final financialControllerProvider =
    StateNotifierProvider<FinancialController, FinancialCenterState>(
  (ref) => FinancialController(ref.watch(financialRepositoryProvider)),
);
