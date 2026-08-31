import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/media/image_pick.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Sporcu/veli tarafı — "borcum ne, nasıl öderim".
///
/// Ödeme akışı: kulübün IBAN'ına havale yap, sonra buradan "Ödedim" de ve
/// istersen dekontu yükle. Kulüp onaylayınca borç kapanır.
class MyFeesScreen extends ConsumerStatefulWidget {
  const MyFeesScreen({super.key});

  @override
  ConsumerState<MyFeesScreen> createState() => _MyFeesScreenState();
}

class _MyFeesScreenState extends ConsumerState<MyFeesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final fees = ref.watch(myFeesProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Aidatlarım', style: SwanType.h2(ink)),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myFeesProvider);
                    await ref.read(myFeesProvider.future);
                  },
                  child: fees.when(
                    loading: () => ListView(children: [premiumLoading()]),
                    error: (e, _) =>
                        ListView(children: [premiumError(context, '$e')]),
                    data: (list) => _body(isDark, ink, list),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _body(bool isDark, Color ink, List<FeeRow> list) {
    if (list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 40),
        children: [
          premiumEmpty(
            context,
            icon: Icons.receipt_long_rounded,
            title: 'Borç kaydı yok',
            subtitle: 'Kulübün aidat tanımladığında borçların burada görünür.',
          ),
        ],
      );
    }

    final open = list.where((f) => !f.isPaid).toList();
    final paid = list.where((f) => f.isPaid).toList();
    final total = open.fold<num>(0, (n, f) => n + f.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 132),
      children: [
        _totalCard(isDark, ink, total, open.length),
        const SizedBox(height: 18),
        if (open.isNotEmpty) ...[
          Text('Ödenmemiş', style: SwanType.h3(ink)),
          const SizedBox(height: 10),
          for (final f in open) _feeCard(isDark, ink, f),
          const SizedBox(height: 18),
        ],
        if (paid.isNotEmpty) ...[
          Text('Ödenenler', style: SwanType.h3(ink)),
          const SizedBox(height: 10),
          for (final f in paid) _feeCard(isDark, ink, f),
        ],
      ],
    );
  }

  Widget _totalCard(bool isDark, Color ink, num total, int count) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Toplam borç',
                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(money(total),
                  style: SwanType.h1(total > 0 ? ink : SwanPalette.light.success)),
              const SizedBox(height: 2),
              Text(count == 0 ? 'Borcun yok' : '$count ödenmemiş kalem',
                  style: SwanType.caption(SwanColors.textSecondary)),
            ],
          ),
        ),
        Icon(
            total > 0
                ? Icons.account_balance_wallet_rounded
                : Icons.verified_rounded,
            size: 34,
            color: total > 0 ? kTeal : SwanPalette.light.success),
      ]),
    );
  }

  Widget _feeCard(bool isDark, Color ink, FeeRow f) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final color = f.isPaid
        ? SwanPalette.light.success
        : f.pendingDeclared
            ? SwanPalette.light.warning
            : f.overdue
                ? SwanPalette.light.danger
                : SwanColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: f.overdue && !f.isPaid
                ? SwanPalette.light.danger.withValues(alpha: .35)
                : line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.label, style: SwanType.bodySm(ink, w: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      [
                        if ((f.athleteName ?? '').isNotEmpty) f.athleteName!,
                        if (f.clubName != null) f.clubName!,
                        if (f.dueDate != null)
                          'Son ödeme: ${f.dueDate!.day}.${f.dueDate!.month}.${f.dueDate!.year}',
                      ].join(' · '),
                      style: SwanType.caption(SwanColors.textSecondary)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(f.amount), style: SwanType.h3(ink)),
              const SizedBox(height: 3),
              PremiumStatusChip(
                label: f.statusLabel,
                color: color,
                icon: f.isPaid
                    ? Icons.check_rounded
                    : f.pendingDeclared
                        ? Icons.schedule_rounded
                        : Icons.circle_outlined,
              ),
            ]),
          ]),
          if (!f.isPaid && !f.pendingDeclared) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showIban(f),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: line),
                    ),
                    child: Text('IBAN',
                        style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => _declare(f),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text('Ödedim, bildir',
                        style: SwanType.caption(Colors.white, w: FontWeight.w800)),
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  /// Kulübün havale bilgilerini gösterir — IBAN'a dokununca panoya kopyalar.
  Future<void> _showIban(FeeRow f) async {
    if (f.clubId == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final info = await ref.read(financeServiceProvider).bankInfo(f.clubId!);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 24 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Havale bilgileri', style: SwanType.h3(ink)),
          const SizedBox(height: 16),
          if ((info.iban ?? '').isEmpty)
            Text('Kulüp henüz IBAN tanımlamamış. Kulüple iletişime geç.',
                textAlign: TextAlign.center,
                style: SwanType.caption(SwanColors.textSecondary))
          else ...[
            if ((info.holder ?? '').isNotEmpty)
              _infoLine(ink, 'Hesap sahibi', info.holder!),
            if ((info.bank ?? '').isNotEmpty)
              _infoLine(ink, 'Banka', info.bank!),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: info.iban!));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('IBAN kopyalandı'),
                    backgroundColor: kTeal));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Text(info.iban!,
                      textAlign: TextAlign.center,
                      style: SwanType.bodySm(kTeal, w: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Kopyalamak için dokun',
                      style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Text('Havaleyi yaptıktan sonra "Ödedim, bildir" ile kulübe haber '
                'ver. Kulüp onaylayınca borç kapanır.',
                textAlign: TextAlign.center,
                style: SwanType.caption(SwanColors.textSecondary)),
          ],
        ]),
      ),
    );
  }

  Widget _infoLine(Color ink, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(label,
              style:
                  SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
          const Spacer(),
          Text(value, style: SwanType.caption(ink, w: FontWeight.w700)),
        ]),
      );

  /// Ödeme bildirimi — tutar, yöntem ve isteğe bağlı dekont.
  Future<void> _declare(FeeRow f) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final amountCtrl = TextEditingController(text: '${f.amount.round()}');
    var method = 'havale';
    String? receiptPath;
    var receiptName = '';
    var busy = false;

    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          decoration: BoxDecoration(
            color: surf,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Ödeme bildirimi', style: SwanType.h3(ink)),
            const SizedBox(height: 4),
            Text(f.label,
                style:
                    SwanType.caption(SwanColors.textSecondary)),
            const SizedBox(height: 18),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: SwanType.bodySm(ink, w: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Ödediğin tutar (₺)',
                labelStyle: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              for (final m in const ['havale', 'nakit', 'diger'])
                Expanded(
                  child: GestureDetector(
                    onTap: () => setSheet(() => method = m),
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.only(right: 7),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: method == m
                            ? kTeal
                            : (isDark
                                ? SwanPalette.dark.surfaceAlt
                                : SwanPalette.light.surfaceAlt),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                          m == 'havale'
                              ? 'Havale'
                              : m == 'nakit'
                                  ? 'Nakit'
                                  : 'Diğer',
                          style: SwanType.caption(method == m ? Colors.white : ink, w: FontWeight.w800)),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: busy
                  ? null
                  : () async {
                      final picked = await pickImage();
                      if (picked == null) return;
                      setSheet(() => busy = true);
                      try {
                        final path = await ref
                            .read(financeServiceProvider)
                            .uploadReceipt(picked.bytes, picked.name);
                        setSheet(() {
                          receiptPath = path;
                          receiptName = picked.name;
                          busy = false;
                        });
                      } catch (_) {
                        setSheet(() => busy = false);
                      }
                    },
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        receiptPath == null
                            ? Icons.attach_file_rounded
                            : Icons.check_circle_rounded,
                        size: 17,
                        color: receiptPath == null
                            ? SwanColors.textSecondary
                            : SwanPalette.light.success),
                    const SizedBox(width: 8),
                    Text(
                        busy
                            ? 'Yükleniyor…'
                            : receiptPath == null
                                ? 'Dekont ekle (isteğe bağlı)'
                                : receiptName,
                        style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: busy ? null : () => Navigator.pop(ctx, true),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text('Bildirimi gönder',
                    style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
              ),
            ),
          ]),
        );
      }),
    );

    if (sent != true) return;

    try {
      await ref.read(financeServiceProvider).declarePayment(
            invoiceId: f.invoiceId,
            amount: num.tryParse(amountCtrl.text.replaceAll(',', '.')),
            method: method,
            receiptPath: receiptPath,
          );
      ref.invalidate(myFeesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bildirimin kulübe iletildi'),
            backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gönderilemedi: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    }
  }
}
