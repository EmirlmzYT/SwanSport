import 'package:swansport_models/swansport_models.dart';

enum ChargeStatus {
  draft,
  scheduled,
  issued,
  partiallyPaid,
  paid,
  overdue,
  cancelled,
  refunded,
  writtenOff,
}

enum PaymentStatus {
  pending,
  completed,
  failed,
  cancelled,
  reversed,
  partiallyApplied,
  unmatched,
}

enum PaymentMethod {
  cash,
  bankTransfer,
  creditCard,
  standingOrder,
  sponsorDirect,
  creditBalance,
  split,
}

enum InstallmentStatus {
  active,
  completed,
  overdue,
  restructured,
  cancelled,
  defaulted,
}

enum ExpenseStatus {
  draft,
  submitted,
  approved,
  rejected,
  paid,
  cancelled,
}

enum FinancialAlertSeverity {
  information,
  warning,
  critical,
}

enum FinancialRole {
  clubOwner,
  administrator,
  financialManager,
  accountant,
  branchManager,
  facilityManager,
  coach,
  parent,
  athlete,
  medicalStaff,
  auditor,
}

enum FeeType {
  membership,
  registration,
  camp,
  tournament,
  equipment,
  custom,
}

enum RefundStatus { requested, approved, rejected, completed }

enum ExportFormat { pdf, excel, csv }

enum ExportState { demoReady, requested }

enum FinancialAuditAction {
  payment,
  refund,
  invoice,
  budgetEdit,
  adjustment,
  export,
  permissionChange,
}

class FinancialPermissions {
  final bool canViewExecutiveDashboard;
  final bool canManageBilling;
  final bool canRecordPayments;
  final bool canApproveExpenses;
  final bool canProcessRefunds;
  final bool canViewCashAccounts;
  final bool canWriteOffDebt;

  const FinancialPermissions({
    required this.canViewExecutiveDashboard,
    required this.canManageBilling,
    required this.canRecordPayments,
    required this.canApproveExpenses,
    required this.canProcessRefunds,
    required this.canViewCashAccounts,
    required this.canWriteOffDebt,
  });
}

FinancialPermissions permissionsForFinancialRole(FinancialRole role) {
  switch (role) {
    case FinancialRole.clubOwner:
    case FinancialRole.financialManager:
      return const FinancialPermissions(
        canViewExecutiveDashboard: true,
        canManageBilling: true,
        canRecordPayments: true,
        canApproveExpenses: true,
        canProcessRefunds: true,
        canViewCashAccounts: true,
        canWriteOffDebt: true,
      );
    case FinancialRole.accountant:
      return const FinancialPermissions(
        canViewExecutiveDashboard: true,
        canManageBilling: true,
        canRecordPayments: true,
        canApproveExpenses: false,
        canProcessRefunds: true,
        canViewCashAccounts: true,
        canWriteOffDebt: false,
      );
    case FinancialRole.administrator:
      return const FinancialPermissions(
        canViewExecutiveDashboard: true,
        canManageBilling: true,
        canRecordPayments: true,
        canApproveExpenses: true,
        canProcessRefunds: false,
        canViewCashAccounts: true,
        canWriteOffDebt: false,
      );
    case FinancialRole.branchManager:
      return const FinancialPermissions(
        canViewExecutiveDashboard: false,
        canManageBilling: true,
        canRecordPayments: true,
        canApproveExpenses: false,
        canProcessRefunds: false,
        canViewCashAccounts: true,
        canWriteOffDebt: false,
      );
    case FinancialRole.facilityManager:
      return const FinancialPermissions(
        canViewExecutiveDashboard: false,
        canManageBilling: false,
        canRecordPayments: false,
        canApproveExpenses: true,
        canProcessRefunds: false,
        canViewCashAccounts: false,
        canWriteOffDebt: false,
      );
    case FinancialRole.auditor:
      return const FinancialPermissions(
        canViewExecutiveDashboard: true,
        canManageBilling: false,
        canRecordPayments: false,
        canApproveExpenses: false,
        canProcessRefunds: false,
        canViewCashAccounts: true,
        canWriteOffDebt: false,
      );
    case FinancialRole.parent:
    case FinancialRole.athlete:
    case FinancialRole.coach:
    case FinancialRole.medicalStaff:
      return const FinancialPermissions(
        canViewExecutiveDashboard: false,
        canManageBilling: false,
        canRecordPayments: false,
        canApproveExpenses: false,
        canProcessRefunds: false,
        canViewCashAccounts: false,
        canWriteOffDebt: false,
      );
  }
}

class AthleteFeeProfile {
  final SwanId id;
  final SwanId athleteId;
  final String athleteName;
  final FeeType feeType;
  final double grossAmount;
  final double discount;
  final double scholarship;
  final double manualAdjustment;
  final String notes;
  final ChargeStatus status;

  const AthleteFeeProfile({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    required this.feeType,
    required this.grossAmount,
    required this.discount,
    required this.scholarship,
    required this.manualAdjustment,
    required this.notes,
    required this.status,
  });

  double get netAmount =>
      (grossAmount - discount - scholarship + manualAdjustment)
          .clamp(0, double.infinity);
}

class RefundRecord {
  final SwanId id;
  final SwanId paymentId;
  final String athleteName;
  final double amount;
  final DateTime requestedAt;
  final RefundStatus status;
  final String reason;

  const RefundRecord({
    required this.id,
    required this.paymentId,
    required this.athleteName,
    required this.amount,
    required this.requestedAt,
    required this.status,
    required this.reason,
  });
}

class ReceiptRecord {
  final SwanId id;
  final String receiptNo;
  final SwanId paymentId;
  final DateTime issuedAt;
  final double amount;
  final ExportState exportState;

  const ReceiptRecord({
    required this.id,
    required this.receiptNo,
    required this.paymentId,
    required this.issuedAt,
    required this.amount,
    required this.exportState,
  });
}

class BudgetRecord {
  final SwanId id;
  final String department;
  final int year;
  final int? month;
  final double planned;
  final double actual;

  const BudgetRecord({
    required this.id,
    required this.department,
    required this.year,
    this.month,
    required this.planned,
    required this.actual,
  });

  double get variance => actual - planned;
  double get remaining => planned - actual;
  bool get exceeded => actual > planned;
}

class CashFlowPoint {
  final String period;
  final double income;
  final double expense;
  final double projectedCollections;
  final double upcomingObligations;

  const CashFlowPoint({
    required this.period,
    required this.income,
    required this.expense,
    required this.projectedCollections,
    required this.upcomingObligations,
  });

  double get net => income - expense;
  double get forecast =>
      income + projectedCollections - expense - upcomingObligations;
}

class FinancialAuditEntry {
  final SwanId id;
  final FinancialAuditAction action;
  final String actor;
  final DateTime occurredAt;
  final String entityReference;
  final String summary;

  const FinancialAuditEntry({
    required this.id,
    required this.action,
    required this.actor,
    required this.occurredAt,
    required this.entityReference,
    required this.summary,
  });
}

class FinancialExportRecord {
  final SwanId id;
  final ExportFormat format;
  final ExportState state;
  final DateTime requestedAt;
  final String requestedBy;

  const FinancialExportRecord({
    required this.id,
    required this.format,
    required this.state,
    required this.requestedAt,
    required this.requestedBy,
  });
}

class FeePlan {
  final SwanId id;
  final String title;
  final String frequency;
  final double amount;
  final int gracePeriodDays;
  final String scope;
  final bool isActive;

  const FeePlan({
    required this.id,
    required this.title,
    required this.frequency,
    required this.amount,
    required this.gracePeriodDays,
    required this.scope,
    required this.isActive,
  });
}

class InvoiceRecord {
  final SwanId id;
  final String documentNo;
  final String payerName;
  final String athleteName;
  final DateTime issueDate;
  final DateTime dueDate;
  final double totalAmount;
  final double paidAmount;
  final ChargeStatus status;

  const InvoiceRecord({
    required this.id,
    required this.documentNo,
    required this.payerName,
    required this.athleteName,
    required this.issueDate,
    required this.dueDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
  });

  double get remainingAmount => totalAmount - paidAmount;
}

class PaymentRecord {
  final SwanId id;
  final String payerName;
  final SwanId athleteId;
  final double amount;
  final DateTime paymentDate;
  final PaymentMethod method;
  final String branch;
  final String referenceNo;
  final PaymentStatus status;

  const PaymentRecord({
    required this.id,
    required this.payerName,
    required this.athleteId,
    required this.amount,
    required this.paymentDate,
    required this.method,
    required this.branch,
    required this.referenceNo,
    required this.status,
  });
}

class InstallmentPlan {
  final SwanId id;
  final SwanId athleteId;
  final String athleteName;
  final double originalAmount;
  final double paidAmount;
  final int totalInstallments;
  final DateTime nextDueDate;
  final int overdueInstallmentsCount;
  final InstallmentStatus status;

  const InstallmentPlan({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    required this.originalAmount,
    required this.paidAmount,
    required this.totalInstallments,
    required this.nextDueDate,
    required this.overdueInstallmentsCount,
    required this.status,
  });

  double get remainingAmount => originalAmount - paidAmount;
  double get completionPercentage =>
      originalAmount > 0 ? (paidAmount / originalAmount) * 100 : 0;
}

class DebtRecord {
  final SwanId id;
  final SwanId athleteId;
  final String athleteName;
  final String parentName;
  final double overdueBalance;
  final int overdueDays;
  final String branch;
  final String riskCategory;

  const DebtRecord({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    required this.parentName,
    required this.overdueBalance,
    required this.overdueDays,
    required this.branch,
    required this.riskCategory,
  });

  String get agingCategory {
    if (overdueDays <= 7) return '1-7 Gün';
    if (overdueDays <= 30) return '8-30 Gün';
    if (overdueDays <= 60) return '31-60 Gün';
    if (overdueDays <= 90) return '61-90 Gün';
    return '90+ Gün';
  }
}

class ExpenseRecord {
  final SwanId id;
  final String category;
  final double amount;
  final String vendor;
  final String branch;
  final String costCenter;
  final String responsibleUser;
  final ExpenseStatus status;
  final DateTime incurredDate;

  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.amount,
    required this.vendor,
    required this.branch,
    required this.costCenter,
    required this.responsibleUser,
    required this.status,
    required this.incurredDate,
  });
}

class FinancialAlert {
  final SwanId id;
  final String title;
  final String message;
  final FinancialAlertSeverity severity;
  final double amount;

  const FinancialAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.amount,
  });
}

class ExecutiveFinancialMetrics {
  final double totalExpectedRevenue;
  final double totalCollectedRevenue;
  final double outstandingReceivables;
  final double overdueDebt;
  final int collectionRate;
  final double currentMonthRevenue;
  final double currentMonthExpenses;
  final double netCashPosition;
  final double availableCash;
  final int financialHealthScore;

  const ExecutiveFinancialMetrics({
    required this.totalExpectedRevenue,
    required this.totalCollectedRevenue,
    required this.outstandingReceivables,
    required this.overdueDebt,
    required this.collectionRate,
    required this.currentMonthRevenue,
    required this.currentMonthExpenses,
    required this.netCashPosition,
    required this.availableCash,
    required this.financialHealthScore,
  });
}

class FinancialFilter {
  final String query;
  final String? branch;
  final ChargeStatus? status;
  final bool? onlyOverdue;

  const FinancialFilter({
    this.query = '',
    this.branch,
    this.status,
    this.onlyOverdue,
  });

  bool matchesInvoice(InvoiceRecord inv) {
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final matchDoc = inv.documentNo.toLowerCase().contains(q);
      final matchPayer = inv.payerName.toLowerCase().contains(q);
      final matchAthlete = inv.athleteName.toLowerCase().contains(q);
      if (!matchDoc && !matchPayer && !matchAthlete) return false;
    }
    if (status != null && inv.status != status) return false;
    if (onlyOverdue == true && inv.status != ChargeStatus.overdue) return false;
    return true;
  }
}

class FixtureFinancialRepository {
  final List<AthleteFeeProfile> _feeProfiles = [
    const AthleteFeeProfile(
      id: SwanId('fee_1'),
      athleteId: SwanId('athlete_1'),
      athleteName: 'Arda Yılmaz',
      feeType: FeeType.membership,
      grossAmount: 3000,
      discount: 250,
      scholarship: 0,
      manualAdjustment: -50,
      notes: 'Kardeş indirimi',
      status: ChargeStatus.paid,
    ),
    const AthleteFeeProfile(
      id: SwanId('fee_2'),
      athleteId: SwanId('athlete_3'),
      athleteName: 'Ece Sönmez',
      feeType: FeeType.tournament,
      grossAmount: 2500,
      discount: 0,
      scholarship: 500,
      manualAdjustment: 0,
      notes: 'Başarı bursu',
      status: ChargeStatus.overdue,
    ),
  ];

  final List<RefundRecord> _refunds = [
    RefundRecord(
      id: const SwanId('refund_1'),
      paymentId: const SwanId('pay_1'),
      athleteName: 'Arda Yılmaz',
      amount: 350,
      requestedAt: DateTime(2026, 7, 22),
      status: RefundStatus.requested,
      reason: 'Etkinlik iptali',
    ),
  ];

  final List<ReceiptRecord> _receipts = [
    ReceiptRecord(
      id: const SwanId('receipt_1'),
      receiptNo: 'RCP-2026-001',
      paymentId: const SwanId('pay_1'),
      issuedAt: DateTime(2026, 7, 5),
      amount: 2500,
      exportState: ExportState.demoReady,
    ),
  ];

  final List<BudgetRecord> _budgets = [
    const BudgetRecord(
      id: SwanId('budget_1'),
      department: 'Futbol',
      year: 2026,
      planned: 180000,
      actual: 142000,
    ),
    const BudgetRecord(
      id: SwanId('budget_2'),
      department: 'Tesis',
      year: 2026,
      month: 7,
      planned: 20000,
      actual: 21500,
    ),
  ];

  final List<CashFlowPoint> _cashFlow = const [
    CashFlowPoint(
      period: 'Haziran',
      income: 72000,
      expense: 51000,
      projectedCollections: 9000,
      upcomingObligations: 6000,
    ),
    CashFlowPoint(
      period: 'Temmuz',
      income: 84000,
      expense: 63000,
      projectedCollections: 12000,
      upcomingObligations: 8500,
    ),
  ];

  final List<FinancialAuditEntry> _audit = [
    FinancialAuditEntry(
      id: const SwanId('faudit_1'),
      action: FinancialAuditAction.payment,
      actor: 'Finans Yöneticisi',
      occurredAt: DateTime(2026, 7, 5, 14, 30),
      entityReference: 'INV-2026-001',
      summary: '2.500 TL ödeme kaydedildi.',
    ),
  ];

  final List<InvoiceRecord> _invoices = [
    InvoiceRecord(
      id: const SwanId('inv_101'),
      documentNo: 'INV-2026-001',
      payerName: 'Mehmet Yılmaz',
      athleteName: 'Arda Yılmaz',
      issueDate: DateTime(2026, 7, 1),
      dueDate: DateTime(2026, 7, 15),
      totalAmount: 2500.0,
      paidAmount: 2500.0,
      status: ChargeStatus.paid,
    ),
    InvoiceRecord(
      id: const SwanId('inv_102'),
      documentNo: 'INV-2026-002',
      payerName: 'Zeynep Erkin',
      athleteName: 'Caner Erkin',
      issueDate: DateTime(2026, 7, 1),
      dueDate: DateTime(2026, 7, 15),
      totalAmount: 3500.0,
      paidAmount: 1500.0,
      status: ChargeStatus.partiallyPaid,
    ),
    InvoiceRecord(
      id: const SwanId('inv_103'),
      documentNo: 'INV-2026-003',
      payerName: 'Ayşe Sönmez',
      athleteName: 'Ece Sönmez',
      issueDate: DateTime(2026, 6, 1),
      dueDate: DateTime(2026, 6, 15),
      totalAmount: 2000.0,
      paidAmount: 0.0,
      status: ChargeStatus.overdue,
    ),
  ];

  final List<PaymentRecord> _payments = [
    PaymentRecord(
      id: const SwanId('pay_1'),
      payerName: 'Mehmet Yılmaz',
      athleteId: const SwanId('athlete_1'),
      amount: 2500.0,
      paymentDate: DateTime(2026, 7, 5),
      method: PaymentMethod.creditCard,
      branch: 'Kadıköy Şubesi',
      referenceNo: 'POS-884920',
      status: PaymentStatus.completed,
    ),
    PaymentRecord(
      id: const SwanId('pay_2'),
      payerName: 'Zeynep Erkin',
      athleteId: const SwanId('athlete_2'),
      amount: 1500.0,
      paymentDate: DateTime(2026, 7, 10),
      method: PaymentMethod.bankTransfer,
      branch: 'Ataşehir Şubesi',
      referenceNo: 'EFT-774819',
      status: PaymentStatus.completed,
    ),
  ];

  final List<InstallmentPlan> _installmentPlans = [
    InstallmentPlan(
      id: const SwanId('inst_1'),
      athleteId: const SwanId('athlete_2'),
      athleteName: 'Caner Erkin',
      originalAmount: 12000.0,
      paidAmount: 6000.0,
      totalInstallments: 6,
      nextDueDate: DateTime(2026, 8, 15),
      overdueInstallmentsCount: 0,
      status: InstallmentStatus.active,
    ),
  ];

  final List<DebtRecord> _debts = [
    const DebtRecord(
      id: SwanId('debt_1'),
      athleteId: SwanId('athlete_3'),
      athleteName: 'Ece Sönmez',
      parentName: 'Ayşe Sönmez',
      overdueBalance: 2000.0,
      overdueDays: 39,
      branch: 'Kadıköy Şubesi',
      riskCategory: 'Yüksek Risk',
    ),
  ];

  final List<ExpenseRecord> _expenses = [
    ExpenseRecord(
      id: const SwanId('exp_1'),
      category: 'Saha Kirası',
      amount: 15000.0,
      vendor: 'Belediye Spor Tesisleri',
      branch: 'Kadıköy Şubesi',
      costCenter: 'CC-FOOTBALL-01',
      responsibleUser: 'Ahmet Şahin (Şube Müdürü)',
      status: ExpenseStatus.approved,
      incurredDate: DateTime(2026, 7, 2),
    ),
    ExpenseRecord(
      id: const SwanId('exp_2'),
      category: 'Malzeme Alımı',
      amount: 4500.0,
      vendor: 'Sportive A.Ş.',
      branch: 'Ataşehir Şubesi',
      costCenter: 'CC-BASKETBALL-02',
      responsibleUser: 'Elif Kaya',
      status: ExpenseStatus.submitted,
      incurredDate: DateTime(2026, 7, 20),
    ),
  ];

  final List<FinancialAlert> _alerts = [
    const FinancialAlert(
      id: SwanId('fin_alert_1'),
      title: 'Gecikmiş Aidat Borcu (>30 Gün)',
      message:
          'Ece Sönmez ailesinin 2.000 TL tutarındaki aidat ödemesi 39 gündür gecikmede.',
      severity: FinancialAlertSeverity.critical,
      amount: 2000.0,
    ),
    const FinancialAlert(
      id: SwanId('fin_alert_2'),
      title: 'Onay Bekleyen Yüksek Gider',
      message:
          'Sportive A.Ş. firmasından 4.500 TL tutarında malzeme gideri onay bekliyor.',
      severity: FinancialAlertSeverity.warning,
      amount: 4500.0,
    ),
  ];

  List<InvoiceRecord> get invoices => List.unmodifiable(_invoices);
  List<PaymentRecord> get payments => List.unmodifiable(_payments);
  List<InstallmentPlan> get installmentPlans =>
      List.unmodifiable(_installmentPlans);
  List<DebtRecord> get debts => List.unmodifiable(_debts);
  List<ExpenseRecord> get expenses => List.unmodifiable(_expenses);
  List<FinancialAlert> get alerts => List.unmodifiable(_alerts);
  List<AthleteFeeProfile> get feeProfiles => List.unmodifiable(_feeProfiles);
  List<RefundRecord> get refunds => List.unmodifiable(_refunds);
  List<ReceiptRecord> get receipts => List.unmodifiable(_receipts);
  List<BudgetRecord> get budgets => List.unmodifiable(_budgets);
  List<CashFlowPoint> get cashFlow => List.unmodifiable(_cashFlow);
  List<FinancialAuditEntry> get audit => List.unmodifiable(_audit);

  ExecutiveFinancialMetrics get metrics {
    final expected = _invoices.fold<double>(0, (sum, i) => sum + i.totalAmount);
    final collected = _invoices.fold<double>(0, (sum, i) => sum + i.paidAmount);
    final outstanding = expected - collected;
    final overdue = _debts.fold<double>(0, (sum, d) => sum + d.overdueBalance);
    final rate = expected > 0 ? ((collected / expected) * 100).round() : 0;
    final monthExp = _expenses.fold<double>(0, (sum, e) => sum + e.amount);

    return ExecutiveFinancialMetrics(
      totalExpectedRevenue: expected,
      totalCollectedRevenue: collected,
      outstandingReceivables: outstanding,
      overdueDebt: overdue,
      collectionRate: rate,
      currentMonthRevenue: collected,
      currentMonthExpenses: monthExp,
      netCashPosition: collected - monthExp + 125000.0,
      availableCash: 125000.0,
      financialHealthScore: 84,
    );
  }

  void recordPayment(SwanId invoiceId, double amount, PaymentMethod method) {
    final idx = _invoices.indexWhere((i) => i.id == invoiceId);
    if (idx == -1) return;
    final inv = _invoices[idx];
    final newPaid = inv.paidAmount + amount;
    final newStatus = newPaid >= inv.totalAmount
        ? ChargeStatus.paid
        : ChargeStatus.partiallyPaid;

    _invoices[idx] = InvoiceRecord(
      id: inv.id,
      documentNo: inv.documentNo,
      payerName: inv.payerName,
      athleteName: inv.athleteName,
      issueDate: inv.issueDate,
      dueDate: inv.dueDate,
      totalAmount: inv.totalAmount,
      paidAmount: newPaid,
      status: newStatus,
    );
  }

  void approveExpense(SwanId expenseId) {
    final idx = _expenses.indexWhere((e) => e.id == expenseId);
    if (idx == -1) return;
    final exp = _expenses[idx];
    _expenses[idx] = ExpenseRecord(
      id: exp.id,
      category: exp.category,
      amount: exp.amount,
      vendor: exp.vendor,
      branch: exp.branch,
      costCenter: exp.costCenter,
      responsibleUser: exp.responsibleUser,
      status: ExpenseStatus.approved,
      incurredDate: exp.incurredDate,
    );
  }
}
