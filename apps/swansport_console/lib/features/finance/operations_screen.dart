import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'work_queue.dart';

/// Mali iş kuyruğu.
///
/// Defter satırları "ne oldu" sorusunu, bu ekran "önce neyi tamamlamalıyım"
/// sorusunu cevaplar.
///
/// Özet `acc_operations_summary` RPC'sinden geliyor ve **hiçbir sporcu ya da
/// veli kimliği taşımıyor** — muhasebeci de kulüp yöneticisi de aynı ekranı
/// görüyor. Ayrım arayüzde değil, veri katmanında.
class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(financeOperationsSummaryProvider);
    final approvals = ref.watch(pendingApprovalsProvider);

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        const ConsolePageHeader(
          title: 'Mali İş Kuyruğu',
          subtitle: 'Kapanışa ve günlük takibe takılan kayıtlar. Özet kişi '
              'adı içermez; muhasebeci gizliliği veri katmanında korunuyor.',
        ),
        const SizedBox(height: ConsoleDensity.xl),
        AsyncSection<FinanceOperationsSummary>(
          value: summary,
          errorPrefix: 'Mali iş kuyruğu alınamadı',
          builder: (s) => WorkQueue(
            top: s.topItems,
            others: s.otherItems,
            emptyTitle: 'Şu anda mali işlem beklemiyor',
            emptyBody: 'Taslak gider, bekleyen onay, hesabına bağlanmamış '
                'hareket ve gecikmiş tahsilat yok.',
          ),
        ),
        const SizedBox(height: ConsoleDensity.xxl),
        Text('Onayımı bekleyen giderler',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.xs),
        Text(
          'Kendi girdiğin gider bu listede çıkmaz — kimse kendi kaydını '
          'onaylayamıyor.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: ConsoleDensity.lg),
        AsyncSection<List<ExpenseRow>>(
          value: approvals,
          errorPrefix: 'Onay listesi alınamadı',
          builder: (rows) => rows.isEmpty
              ? Text('Onayını bekleyen gider yok.',
                  style: Theme.of(context).textTheme.bodySmall)
              : Column(
                  children: [
                    for (final e in rows) _ApprovalRow(expense: e),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Onay bekleyen tek gider satırı.
class _ApprovalRow extends ConsumerStatefulWidget {
  const _ApprovalRow({required this.expense});

  final ExpenseRow expense;

  @override
  ConsumerState<_ApprovalRow> createState() => _ApprovalRowState();
}

class _ApprovalRowState extends ConsumerState<_ApprovalRow> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    String? reason;

    // Red gerekçesi zorunlu: gerekçesiz red, kaydı giren kişiye ne
    // düzelteceğini söylemiyor ve kayıt kuyrukta çürüyor. Şema da bunu
    // kısıtla zorluyor; burada sormak, sunucu hatasını beklemekten iyi.
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _RejectDialog(),
      );
      if (reason == null) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(financeOpsServiceProvider)
          .decideApproval(widget.expense.id, approve, reason: reason);
      ref.invalidate(pendingApprovalsProvider);
      ref.invalidate(financeOperationsSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve ? 'Gider onaylandı' : 'Gider reddedildi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final e = widget.expense;

    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: t.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    e.categoryName,
                    e.supplier,
                  ].where((x) => (x ?? '').isNotEmpty).join(' · '),
                  style: t.textTheme.titleSmall,
                ),
                Text(
                  '${fmtDate(e.spentOn)}'
                  '${e.note == null || e.note!.isEmpty ? '' : ' · ${e.note}'}',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(fmtMoney(e.amount), style: t.textTheme.titleSmall),
          const SizedBox(width: ConsoleDensity.lg),
          if (_busy)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            TextButton(
              onPressed: () => _decide(false),
              child: const Text('Reddet'),
            ),
            const SizedBox(width: ConsoleDensity.sm),
            FilledButton(
              onPressed: () => _decide(true),
              child: const Text('Onayla'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gideri reddet'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _c,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Gerekçe',
            hintText: 'Kaydı giren kişi bunu görecek ve buna göre düzeltecek.',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _c.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _c.text.trim()),
          child: const Text('Reddet'),
        ),
      ],
    );
  }
}
