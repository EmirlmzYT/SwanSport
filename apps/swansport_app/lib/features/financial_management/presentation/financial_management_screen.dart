import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/financial_controller.dart';
import '../domain/financial_management.dart';
import 'financial_route_args.dart';

class FinancialManagementScreen extends ConsumerWidget {
  const FinancialManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financialControllerProvider);
    final c = ref.read(financialControllerProvider.notifier);
    final metrics = state.metrics;

    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.hasFinancialAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finans Yönetimi')),
        body: Center(
          child: Semantics(
            label: 'Finans kayıtlarına erişim reddedildi',
            child: const Text(
              'Bu rol finansal verilere erişemez.',
              key: Key('financial-access-denied'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finans Yönetimi & Aidat Takibi'),
        actions: [
          DropdownButton<FinancialRole>(
            key: const Key('financial-role-switcher'),
            value: state.currentRole,
            onChanged: (role) {
              if (role != null) c.changeRole(role);
            },
            items: FinancialRole.values
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.name),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final overview = Column(
            children: [
              Container(
                key: const Key('financial-command-center'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FINANCIAL COMMAND CENTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${metrics.totalCollectedRevenue.toStringAsFixed(0)} TL / ${metrics.totalExpectedRevenue.toStringAsFixed(0)} TL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tahsilat Oranı: %${metrics.collectionRate} • Alacak: ${metrics.outstandingReceivables.toStringAsFixed(0)} TL • Gecikmiş: ${metrics.overdueDebt.toStringAsFixed(0)} TL • Kasa: ${metrics.availableCash.toStringAsFixed(0)} TL',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  key: const Key('financial-alerts-tile'),
                  title: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mali Riskler & Uyarilar (${state.alerts.length})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    if (state.alerts.isEmpty)
                      const ListTile(
                        title: Text('Aktif mali risk uyarısı yok.'),
                      )
                    else
                      for (final a in state.alerts)
                        ListTile(
                          key: Key('fin-alert-${a.id.value}'),
                          leading: Icon(
                            a.severity == FinancialAlertSeverity.critical
                                ? Icons.error
                                : Icons.info,
                            color: a.severity == FinancialAlertSeverity.critical
                                ? Colors.red
                                : Colors.amber,
                          ),
                          title: Text(a.title),
                          subtitle: Text(
                            '${a.message} • Tutar: ${a.amount.toStringAsFixed(0)} TL',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () => c.dismissAlert(a.id),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );

          final directory = Column(
            children: [
              TextField(
                key: const Key('financial-search'),
                onChanged: c.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Belge No, veli, sporcu veya tutar ara...',
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: state.filter.status == null,
                      onSelected: (_) => c.filterStatus(null),
                    ),
                    ...ChargeStatus.values.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(_statusLabel(s)),
                          selected: state.filter.status == s,
                          onSelected: (_) => c.filterStatus(s),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (state.filteredInvoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Eşleşen finans kaydı bulunamadı.',
                    key: Key('financial-empty'),
                  ),
                ),
              for (final inv in state.filteredInvoices)
                Card(
                  child: ListTile(
                    key: Key('invoice-${inv.id.value}'),
                    leading: _statusIcon(inv.status),
                    title: Text('${inv.documentNo} - ${inv.athleteName}'),
                    subtitle: Text(
                      '${state.canViewPayerIdentity ? 'Veli: ${inv.payerName}\n' : ''}Toplam: ${inv.totalAmount.toStringAsFixed(0)} TL • Ödenen: ${inv.paidAmount.toStringAsFixed(0)} TL • Durum: ${_statusLabel(inv.status)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/financial-detail',
                      arguments: FinancialDetailArgs(inv.id),
                    ),
                  ),
                ),
            ],
          );

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'FİNANS MERKEZİ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const Text(
                'Gelir & Gider Muhasebesi',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              if (state.permissions.canViewExecutiveDashboard)
                Semantics(
                  label: 'Finansal temel göstergeler; detay için seçilebilir',
                  child: Wrap(
                    key: const Key('financial-kpi-grid'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _kpi(
                        context,
                        'Aylık Gelir',
                        metrics.currentMonthRevenue,
                        'payments',
                      ),
                      _kpi(
                        context,
                        'Aylık Gider',
                        metrics.currentMonthExpenses,
                        'expenses',
                      ),
                      _kpi(
                        context,
                        'Net Bakiye',
                        metrics.netCashPosition,
                        'cash-flow',
                      ),
                      _kpi(
                        context,
                        'Alacaklar',
                        metrics.outstandingReceivables,
                        'invoices',
                      ),
                      _kpi(
                        context,
                        'Gecikmiş Ödemeler',
                        metrics.overdueDebt,
                        'overdue',
                      ),
                      _kpi(
                        context,
                        'İade Talepleri',
                        state.refunds
                            .where((r) => r.status == RefundStatus.requested)
                            .length
                            .toDouble(),
                        'refunds',
                        currency: false,
                      ),
                      _kpi(
                        context,
                        'Aktif Abonelikler',
                        state.installmentPlans
                            .where((p) => p.status == InstallmentStatus.active)
                            .length
                            .toDouble(),
                        'subscriptions',
                        currency: false,
                      ),
                      _kpi(
                        context,
                        'Tahsilat Oranı',
                        metrics.collectionRate.toDouble(),
                        'collection',
                        suffix: '%',
                        currency: false,
                      ),
                    ],
                  ),
                ),
              if (state.permissions.canViewExecutiveDashboard)
                const SizedBox(height: 16),
              if (state.permissions.canViewExecutiveDashboard &&
                  state.canViewInvoiceDirectory &&
                  box.maxWidth >= 840)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: overview),
                    const SizedBox(width: 24),
                    Expanded(flex: 7, child: directory),
                  ],
                )
              else if (state.permissions.canViewExecutiveDashboard &&
                  state.canViewInvoiceDirectory) ...[
                overview,
                const SizedBox(height: 16),
                directory,
              ] else if (state.permissions.canViewExecutiveDashboard) ...[
                overview,
              ] else if (state.canViewInvoiceDirectory) ...[
                directory,
              ],
              if (state.canViewOperations) ...[
                const SizedBox(height: 16),
                _operations(state, c),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _kpi(
    BuildContext context,
    String label,
    double value,
    String drilldown, {
    bool currency = true,
    String suffix = '',
  }) {
    return SizedBox(
      width: 170,
      height: 76,
      child: Card(
        child: InkWell(
          key: Key('financial-kpi-$drilldown'),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label kırılımı görüntüleniyor.')),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, overflow: TextOverflow.ellipsis),
                Text(
                  '${value.toStringAsFixed(0)}${currency ? ' TL' : suffix}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _operations(FinancialCenterState state, FinancialController c) {
    return Column(
      key: const Key('financial-operations'),
      children: [
        _tile(
          'Sporcu Ücretleri & Taksitler',
          'financial-fees',
          [
            for (final fee in state.feeProfiles)
              ListTile(
                title: Text('${fee.athleteName} • ${fee.feeType.name}'),
                subtitle: Text(
                  'Net: ${fee.netAmount.toStringAsFixed(0)} TL • ${_statusLabel(fee.status)}\n${fee.notes}',
                ),
              ),
            for (final plan in state.installmentPlans)
              ListTile(
                title: Text('${plan.athleteName} • Taksit planı'),
                subtitle: Text(
                  '${plan.completionPercentage.toStringAsFixed(0)}% tamamlandı • Kalan ${plan.remainingAmount.toStringAsFixed(0)} TL',
                ),
              ),
          ],
        ),
        _tile(
          'Ödemeler, Makbuzlar & İadeler',
          'financial-payments',
          [
            for (final receipt in state.receipts)
              ListTile(
                title: Text(receipt.receiptNo),
                subtitle: Text(
                  '${receipt.amount.toStringAsFixed(0)} TL • Demo dışa aktarma: ${receipt.exportState.name}',
                ),
              ),
            for (final refund in state.refunds)
              ListTile(
                title: Text('${refund.athleteName} • İade'),
                subtitle: Text(
                  '${refund.amount.toStringAsFixed(0)} TL • ${refund.status.name} • ${refund.reason}',
                ),
              ),
          ],
        ),
        _tile(
          'Bütçe: Planlanan / Gerçekleşen',
          'financial-budget',
          [
            for (final budget in state.budgets)
              ListTile(
                title: Text('${budget.department} • ${budget.year}'),
                subtitle: Text(
                  'Plan ${budget.planned.toStringAsFixed(0)} TL • Gerçek ${budget.actual.toStringAsFixed(0)} TL • Varyans ${budget.variance.toStringAsFixed(0)} TL • Kalan ${budget.remaining.toStringAsFixed(0)} TL',
                ),
                trailing: budget.exceeded
                    ? const Tooltip(
                        message: 'Bütçe aşıldı',
                        child: Icon(Icons.warning_amber),
                      )
                    : const Icon(Icons.check_circle_outline),
              ),
          ],
        ),
        _tile(
          'Nakit Akışı & Tahmin',
          'financial-cash-flow',
          [
            for (final point in state.cashFlow)
              ListTile(
                title: Text(point.period),
                subtitle: Text(
                  'Gelir ${point.income.toStringAsFixed(0)} • Gider ${point.expense.toStringAsFixed(0)} • Net ${point.net.toStringAsFixed(0)} • Tahmin ${point.forecast.toStringAsFixed(0)} TL',
                ),
              ),
          ],
        ),
        _tile(
          'Gider Yönetimi',
          'financial-expenses',
          [
            for (final expense in state.expenses)
              ListTile(
                title: Text('${expense.category} • ${expense.vendor}'),
                subtitle: Text(
                  '${expense.amount.toStringAsFixed(0)} TL • ${expense.incurredDate.toString().split(' ').first} • ${expense.status.name}',
                ),
              ),
          ],
        ),
        _tile(
          'Değiştirilemez Denetim Geçmişi',
          'financial-audit',
          [
            for (final entry in state.audit.reversed)
              ListTile(
                title: Text('${entry.action.name} • ${entry.entityReference}'),
                subtitle: Text('${entry.actor} • ${entry.summary}'),
              ),
          ],
        ),
        Card(
          key: const Key('financial-export-center'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dışa Aktarma Merkezi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Demo mod: gerçek dosya oluşturulmaz. Hassas banka ve kart verileri dahil edilmez.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final format in ExportFormat.values)
                      OutlinedButton(
                        key: Key('financial-export-${format.name}'),
                        onPressed: () => c.requestExport(format),
                        child: Text(format.name.toUpperCase()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(String title, String keyName, List<Widget> children) {
    return Card(
      child: ExpansionTile(
        key: Key(keyName),
        title: Text(title),
        children: children,
      ),
    );
  }

  String _statusLabel(ChargeStatus s) {
    switch (s) {
      case ChargeStatus.draft:
        return 'Taslak';
      case ChargeStatus.scheduled:
        return 'Planlandı';
      case ChargeStatus.issued:
        return 'Yayınlandı';
      case ChargeStatus.partiallyPaid:
        return 'Kısmi Ödendi';
      case ChargeStatus.paid:
        return 'Ödendi';
      case ChargeStatus.overdue:
        return 'Gecikmede';
      case ChargeStatus.cancelled:
        return 'İptal';
      case ChargeStatus.refunded:
        return 'İade Edildi';
      case ChargeStatus.writtenOff:
        return 'Silindi';
    }
  }

  Widget _statusIcon(ChargeStatus s) {
    switch (s) {
      case ChargeStatus.paid:
        return const Icon(Icons.check_circle, color: Colors.green);
      case ChargeStatus.partiallyPaid:
        return const Icon(Icons.pie_chart, color: Colors.blue);
      case ChargeStatus.overdue:
        return const Icon(Icons.error, color: Colors.red);
      case ChargeStatus.issued:
      case ChargeStatus.scheduled:
        return const Icon(Icons.schedule, color: Colors.orange);
      case ChargeStatus.draft:
      case ChargeStatus.cancelled:
      case ChargeStatus.refunded:
      case ChargeStatus.writtenOff:
        return const Icon(Icons.remove_circle_outline, color: Colors.grey);
    }
  }
}

class FinancialDetailScreen extends ConsumerWidget {
  final FinancialDetailArgs? args;

  const FinancialDetailScreen({required this.args, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financialControllerProvider);
    final c = ref.read(financialControllerProvider.notifier);

    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Geçersiz finans belgesi bağlantısı.')),
      );
    }

    final found = state.invoices.where((i) => i.id == args!.invoiceId);
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (found.isEmpty) {
      return const Scaffold(body: Center(child: Text('Fatura bulunamadı.')));
    }

    final inv = found.single;
    final perms = state.permissions;

    return Scaffold(
      appBar: AppBar(title: Text('Fatura ${inv.documentNo}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            inv.documentNo,
            key: const Key('financial-detail-docno'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text('Veli / Ödeyen: ${inv.payerName} • Sporcu: ${inv.athleteName}'),
          Text(
            'Düzenleme: ${inv.issueDate.toString().split(' ')[0]} • Son Ödeme: ${inv.dueDate.toString().split(' ')[0]}',
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toplam Tutar: ${inv.totalAmount.toStringAsFixed(2)} TL',
                  ),
                  Text('Ödenen Tutar: ${inv.paidAmount.toStringAsFixed(2)} TL'),
                  Text(
                    'Kalan Bakiye: ${inv.remainingAmount.toStringAsFixed(2)} TL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          inv.remainingAmount > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (perms.canRecordPayments && inv.remainingAmount > 0)
                    ElevatedButton.icon(
                      key: const Key('record-payment-btn'),
                      onPressed: () => c.recordPayment(
                        inv.id,
                        inv.remainingAmount,
                        PaymentMethod.creditCard,
                      ),
                      icon: const Icon(Icons.payment),
                      label: const Text('Hızlı Ödeme Kaydet (Kredi Kartı)'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Gider Onayları (Kısıtlı Yetki)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final exp in state.expenses)
            Card(
              child: ListTile(
                title: Text(
                  '${exp.category} - ${exp.amount.toStringAsFixed(0)} TL',
                ),
                subtitle: Text(
                  'Firma: ${exp.vendor} • Şube: ${exp.branch}\nSorumlu: ${exp.responsibleUser} • Durum: ${exp.status.name}',
                ),
                trailing: perms.canApproveExpenses &&
                        exp.status == ExpenseStatus.submitted
                    ? ElevatedButton(
                        onPressed: () => c.approveExpense(exp.id),
                        child: const Text('Onayla'),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
