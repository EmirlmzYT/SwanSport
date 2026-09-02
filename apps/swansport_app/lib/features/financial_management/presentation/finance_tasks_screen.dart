import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Mali işler — mobil.
///
/// Mobil bir muhasebe konsolu **değil**; sahadaki hızlı aksiyonu taşıyor:
/// bekleyen işleri görmek ve gider onayı vermek. Ekstre yükleme, bütçe
/// kurma ve dönem kapatma konsolda kalıyor — küçük ekranda yapılan bir
/// kapanış, kontrol listesini okumadan basılan bir düğme olurdu.
///
/// Bildirimlerin varış noktası burası: `push_route` yedi mali bildirim
/// türünü `/mali-isler`e yönlendiriyor.
class FinanceTasksScreen extends ConsumerWidget {
  const FinanceTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final summary = ref.watch(financeOperationsSummaryProvider);
    final approvals = ref.watch(pendingApprovalsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md,
                    SwanSpace.lg, SwanSpace.md),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                          border: Border.all(color: c.line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Text('Mali işler', style: SwanType.h2(c.ink)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      SwanSpace.lg, 0, SwanSpace.lg, 132),
                  children: [
                    summary.when(
                      loading: premiumLoading,
                      error: (e, _) => premiumError(context, '$e'),
                      data: (s) => s.items.isEmpty
                          ? premiumEmpty(
                              context,
                              icon: Icons.check_circle_outline_rounded,
                              title: 'Bekleyen mali iş yok',
                              subtitle: 'Taslak gider, bekleyen onay ve '
                                  'gecikmiş tahsilat bulunmuyor.',
                            )
                          : Column(
                              children: [
                                for (final i in s.topItems) _card(c, i),
                              ],
                            ),
                    ),
                    const SizedBox(height: SwanSpace.xl),
                    approvals.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (rows) => rows.isEmpty
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Onayını bekleyenler',
                                    style: SwanType.h3(c.ink)),
                                const SizedBox(height: SwanSpace.xs),
                                Text(
                                  'Kendi girdiğin gider burada çıkmaz — '
                                  'kimse kendi kaydını onaylayamıyor.',
                                  style: SwanType.caption(c.inkMuted),
                                ),
                                const SizedBox(height: SwanSpace.md),
                                for (final e in rows) _ApprovalTile(expense: e),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _card(SwanPalette c, FinanceWorkItem item) {
    // Renk tek başına bilgi taşımıyor: risk metni de yazılı.
    final tone = switch (item.risk) {
      FinanceRisk.critical => c.danger,
      FinanceRisk.attention => c.warning,
      FinanceRisk.info => c.inkMuted,
    };
    final label = switch (item.risk) {
      FinanceRisk.critical => 'Kritik',
      FinanceRisk.attention => 'Dikkat',
      FinanceRisk.info => 'Bilgi',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.md),
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(item.title,
                style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
          ),
          Text(label, style: SwanType.caption(tone)),
        ]),
        const SizedBox(height: SwanSpace.xs),
        Row(children: [
          Text('${item.count} kayıt', style: SwanType.caption(c.inkMuted)),
          if (item.hasTotal) ...[
            const Spacer(),
            Text(fmtMoney(item.total),
                style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
          ],
        ]),
        const SizedBox(height: SwanSpace.sm),
        Text(item.why, style: SwanType.caption(c.inkMuted)),
      ]),
    );
  }
}

class _ApprovalTile extends ConsumerStatefulWidget {
  const _ApprovalTile({required this.expense});

  final ExpenseRow expense;

  @override
  ConsumerState<_ApprovalTile> createState() => _ApprovalTileState();
}

class _ApprovalTileState extends ConsumerState<_ApprovalTile> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    String? reason;
    if (!approve) {
      // Red gerekçesi zorunlu — sunucu da şema kısıtıyla zorluyor.
      reason = await showDialog<String>(
        context: context,
        builder: (_) => _ReasonDialog(),
      );
      if (reason == null || reason.trim().isEmpty) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(financeOpsServiceProvider)
          .decideApproval(widget.expense.id, approve, reason: reason);
      ref.invalidate(pendingApprovalsProvider);
      ref.invalidate(financeOperationsSummaryProvider);
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
    final c = context.swan;
    final e = widget.expense;

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              [e.categoryName, e.supplier]
                  .where((x) => (x ?? '').isNotEmpty)
                  .join(' · '),
              style: SwanType.bodySm(c.ink, w: FontWeight.w600),
            ),
            Text('${fmtDate(e.spentOn)} · ${fmtMoney(e.amount)}',
                style: SwanType.caption(c.inkMuted)),
          ]),
        ),
        if (_busy)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
        else ...[
          GestureDetector(
            onTap: () => _decide(false),
            child: Padding(
              padding: const EdgeInsets.all(SwanSpace.sm),
              child: Text('Reddet', style: SwanType.caption(c.danger)),
            ),
          ),
          const SizedBox(width: SwanSpace.xs),
          GestureDetector(
            onTap: () => _decide(true),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accentFill,
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
              child: Text('Onayla',
                  style: SwanType.caption(Colors.white, w: FontWeight.w800)),
            ),
          ),
        ],
      ]),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Gideri reddet'),
        content: TextField(
          controller: _c,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Gerekçe',
            hintText: 'Kaydı giren kişi bunu görecek.',
          ),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: _c.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _c.text.trim()),
            child: const Text('Reddet'),
          ),
        ],
      );
}
