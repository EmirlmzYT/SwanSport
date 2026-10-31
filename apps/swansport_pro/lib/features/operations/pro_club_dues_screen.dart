import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/pro_ui_components.dart';

class ProClubDuesScreen extends ConsumerWidget {
  const ProClubDuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(activeClubProvider).valueOrNull;
    if (club == null || club.role != 'club_admin') {
      return const Scaffold(
        body: ProUnauthorizedState(roleName: 'kulüp yöneticisi'),
      );
    }
    final canOpenAccounting = ref.watch(swanAccessProvider).isAccountant;
    final overview = ref.watch(clubDuesOverviewProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aidat & Ödeme Takibi'),
          actions: canOpenAccounting
              ? [
                  IconButton(
                    tooltip: 'Muhasebe çalışma alanı',
                    onPressed: () => context.push('/operasyon/muhasebe'),
                    icon: const Icon(Icons.account_balance_outlined),
                  ),
                ]
              : null,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Aidatlar'),
              Tab(text: 'Ödemeler'),
              Tab(text: 'Planlar'),
            ],
          ),
        ),
        body: overview.when(
          loading: () => const ProLoadingState(
            message: 'Aidat ve ödeme kayıtları yükleniyor…',
          ),
          error: (error, _) => ProErrorState(
            message: classifyOperationError(error).userMessage,
            onRetry: () => ref.invalidate(clubDuesOverviewProvider),
          ),
          data: (data) => Column(
            children: [
              _Summary(summary: data.summary),
              _PeriodFilter(periods: data.periods),
              Expanded(
                child: TabBarView(
                  children: [
                    _InvoicesTab(invoices: data.invoices),
                    _PaymentsTab(payments: data.payments),
                    _PlansTab(plans: data.plans),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final ClubDuesSummary summary;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            _metric('Tahakkuk', money(summary.billed), Icons.receipt_long),
            _metric('Tahsilat', money(summary.collected), Icons.payments),
            _metric('Kalan', money(summary.outstanding), Icons.schedule),
            _metric(
              'Gecikmiş',
              '${summary.overdueCount}',
              Icons.warning_amber,
            ),
            _metric(
              'Onay bekleyen',
              '${summary.pendingPaymentCount}',
              Icons.pending_actions,
            ),
          ],
        ),
      );

  Widget _metric(String label, String value, IconData icon) => SizedBox(
        width: 156,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(label),
              ],
            ),
          ),
        ),
      );
}

class _PeriodFilter extends ConsumerWidget {
  const _PeriodFilter({required this.periods});

  final List<String> periods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(clubDuesPeriodProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String?>(
        key: ValueKey<String?>(selected),
        initialValue: selected,
        decoration: const InputDecoration(
          labelText: 'Dönem',
          prefixIcon: Icon(Icons.calendar_month_outlined),
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Tümü')),
          ...periods.map(
            (period) => DropdownMenuItem<String?>(
              value: period,
              child: Text(period),
            ),
          ),
        ],
        onChanged: (value) {
          ref.read(clubDuesPeriodProvider.notifier).state = value;
        },
      ),
    );
  }
}

class _InvoicesTab extends ConsumerWidget {
  const _InvoicesTab({required this.invoices});

  final List<ClubDueInvoice> invoices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (invoices.isEmpty) {
      return const ProEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Aidat kaydı yok',
        subtitle: 'Seçilen dönem için gerçek tahakkuk bulunamadı.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(clubDuesOverviewProvider);
        await ref.read(clubDuesOverviewProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final invoice = invoices[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoice.athleteName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(label: Text(_statusLabel(invoice.status))),
                    ],
                  ),
                  Text(invoice.label),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text('Borç: ${money(invoice.amount)}'),
                      Text('Ödenen: ${money(invoice.confirmedAmount)}'),
                      Text('Kalan: ${money(invoice.balance)}'),
                      if (invoice.pendingAmount > 0)
                        Text('Bildirim: ${money(invoice.pendingAmount)}'),
                      if (invoice.dueDate != null)
                        Text('Vade: ${_date(invoice.dueDate!)}'),
                    ],
                  ),
                  if (invoice.balance > 0) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _record(context, ref, invoice),
                        icon: const Icon(Icons.add_card_outlined),
                        label: const Text('Tahsilat gir'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    ClubDueInvoice invoice,
  ) async {
    final amount = TextEditingController(text: '${invoice.balance}');
    final note = TextEditingController();
    var method = 'nakit';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tahsilat kaydı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Tutar (en fazla ${money(invoice.balance)})',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Yöntem'),
                items: const [
                  DropdownMenuItem(value: 'nakit', child: Text('Nakit')),
                  DropdownMenuItem(value: 'havale', child: Text('Havale')),
                  DropdownMenuItem(value: 'kart', child: Text('Kart')),
                  DropdownMenuItem(value: 'diger', child: Text('Diğer')),
                ],
                onChanged: (value) => setState(() => method = value ?? method),
              ),
              TextField(
                controller: note,
                decoration:
                    const InputDecoration(labelText: 'Not (isteğe bağlı)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final parsed = num.tryParse(amount.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0 || parsed > invoice.balance) {
      if (context.mounted) _message(context, 'Geçerli bir tutar gir.');
      return;
    }
    final operationId = newFinanceOperationId();
    try {
      await ref.read(clubDuesManagementServiceProvider).recordPayment(
            invoiceId: invoice.id,
            amount: parsed,
            method: method,
            note: note.text.trim(),
            operationId: operationId,
          );
      ref.invalidate(clubDuesOverviewProvider);
      if (context.mounted) _message(context, 'Tahsilat kaydedildi.');
    } catch (error) {
      if (!context.mounted) return;
      _message(
        context,
        'İşlem doğrulanamadı. Yenileyip durumu kontrol et: '
        '${classifyOperationError(error).userMessage}',
      );
    }
  }
}

class _PaymentsTab extends ConsumerWidget {
  const _PaymentsTab({required this.payments});

  final List<ClubPaymentHistoryItem> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (payments.isEmpty) {
      return const ProEmptyState(
        icon: Icons.payments_outlined,
        title: 'Ödeme hareketi yok',
        subtitle: 'Seçilen döneme ait ödeme geçmişi bulunamadı.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return Card(
          child: ListTile(
            title: Text('${payment.athleteName} · ${money(payment.amount)}'),
            subtitle: Text(
              '${payment.label}\n${_date(payment.paidAt)} · '
              '${_statusLabel(payment.status)} · ${payment.method}',
            ),
            isThreeLine: true,
            trailing: payment.status == 'pending'
                ? Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Reddet',
                        onPressed: () => _decide(context, ref, payment, false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton(
                        tooltip: 'Onayla',
                        onPressed: () => _decide(context, ref, payment, true),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  )
                : payment.receiptUrl == null
                    ? null
                    : IconButton(
                        tooltip: 'Dekontu aç',
                        onPressed: () => launchUrl(
                          Uri.parse(payment.receiptUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.description_outlined),
                      ),
            onTap: payment.receiptUrl == null
                ? null
                : () => launchUrl(
                      Uri.parse(payment.receiptUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
          ),
        );
      },
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    ClubPaymentHistoryItem payment,
    bool approve,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Ödeme onaylansın mı?' : 'Ödeme reddedilsin mi?'),
        content: Text(
          '${payment.athleteName} için ${money(payment.amount)} tutarındaki '
          'bildirim sonuçlandırılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'Onayla' : 'Reddet'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(clubDuesManagementServiceProvider).decidePayment(
            payment.id,
            approve: approve,
          );
      ref.invalidate(clubDuesOverviewProvider);
      if (context.mounted) _message(context, 'Ödeme durumu güncellendi.');
    } catch (error) {
      if (!context.mounted) return;
      _message(context, classifyOperationError(error).userMessage);
    }
  }
}

class _PlansTab extends StatelessWidget {
  const _PlansTab({required this.plans});

  final List<FeePlan> plans;

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return const ProEmptyState(
        icon: Icons.price_change_outlined,
        title: 'Aidat planı yok',
        subtitle: 'Kulübe tanımlanmış gerçek aidat planı bulunamadı.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return Card(
          child: ListTile(
            leading: Icon(
              plan.active ? Icons.check_circle_outline : Icons.pause_circle,
            ),
            title: Text(plan.name),
            subtitle: Text('${money(plan.amount)} · Ayın ${plan.dueDay}. günü'),
            trailing: Text(plan.active ? 'Aktif' : 'Pasif'),
          ),
        );
      },
    );
  }
}

String _statusLabel(String status) => switch (status) {
      'paid' => 'Ödendi',
      'partial' => 'Kısmi',
      'overdue' => 'Gecikmiş',
      'confirmed' => 'Onaylandı',
      'rejected' => 'Reddedildi',
      _ => 'Bekliyor',
    };

String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
