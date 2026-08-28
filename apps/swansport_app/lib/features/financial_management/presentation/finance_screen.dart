import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';

/// Kulüp finansı — aidat tahakkuku, tahsilat onayı ve planlar.
///
/// Eski finans ekranı tamamen sahte veriyle çalışıyordu; bu ekran gerçek
/// borç/ödeme kayıtları üzerinde işler.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  int _tab = 0;
  String _period = ''; // boş = tüm dönemler

  String get _thisPeriod {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  void _refresh() {
    ref.invalidate(financeSummaryProvider);
    ref.invalidate(feeLedgerProvider(_period));
    ref.invalidate(pendingPaymentsProvider);
    ref.invalidate(feePlansProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KULÜP FİNANSI',
                            style: jakarta(
                                11, FontWeight.w700, SwanColors.textSecondary,
                                ls: 1.2)),
                        const SizedBox(height: 3),
                        Text('Aidat & Bağış',
                            style: sora(24, FontWeight.w800, ink)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _editBank,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131D2E) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF233149)
                                : const Color(0xFFEAEEF3)),
                      ),
                      child: Icon(Icons.account_balance_rounded,
                          size: 17, color: ink),
                    ),
                  ),
                ]),
              ),
              _tabBar(isDark, ink),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    await ref.read(financeSummaryProvider.future);
                  },
                  child: switch (_tab) {
                    1 => _paymentsTab(isDark, ink),
                    2 => _plansTab(isDark, ink),
                    _ => _ledgerTab(isDark, ink),
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: -1,
        onSelect: (_) {},
        onAction: () {},
      ),
    );
  }

  Widget _tabBar(bool isDark, Color ink) {
    const labels = ['Borçlar', 'Ödemeler', 'Planlar'];
    final pending =
        ref.watch(financeSummaryProvider).valueOrNull?.pendingPayments ?? 0;

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        itemBuilder: (_, i) {
          final active = _tab == i;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? kTeal
                    : (isDark ? const Color(0xFF1A2537) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: active
                        ? kTeal
                        : (isDark
                            ? const Color(0xFF233149)
                            : const Color(0xFFEAEEF3))),
              ),
              child: Row(children: [
                Text(labels[i],
                    style: jakarta(12.5, FontWeight.w800,
                        active ? Colors.white : ink)),
                if (i == 1 && pending > 0) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: .25)
                          : const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$pending',
                        style: jakarta(10, FontWeight.w800, Colors.white)),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------ 1) BORÇLAR -------------------------------
  Widget _ledgerTab(bool isDark, Color ink) {
    final ledger = ref.watch(feeLedgerProvider(_period));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
      children: [
        _summaryCard(isDark, ink),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _button(isDark, Icons.playlist_add_rounded,
                'Bu ayı tahakkuk ettir', _generate),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _button(
                isDark, Icons.add_rounded, 'Tek seferlik borç', _addExtra,
                subtle: true),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Text('BORÇ LİSTESİ',
              style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                  ls: 1.2)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(
                () => _period = _period.isEmpty ? _thisPeriod : ''),
            child: Text(_period.isEmpty ? 'Tümü' : _period,
                style: jakarta(11.5, FontWeight.w800, kTeal)),
          ),
        ]),
        const SizedBox(height: 10),
        ledger.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? premiumEmpty(
                  context,
                  icon: Icons.receipt_long_rounded,
                  title: 'Borç kaydı yok',
                  subtitle:
                      'Önce bir aidat planı tanımlayıp sporculara ata, sonra '
                      '"Bu ayı tahakkuk ettir" de.',
                )
              : Column(children: [for (final f in list) _feeRow(isDark, ink, f)]),
        ),
      ],
    );
  }

  Widget _summaryCard(bool isDark, Color ink) {
    final s = ref.watch(financeSummaryProvider).valueOrNull;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tahsil edilen',
                    style: jakarta(
                        10.5, FontWeight.w600, SwanColors.textSecondary)),
                const SizedBox(height: 3),
                Text(money(s?.collected ?? 0),
                    style: sora(22, FontWeight.w800, ink)),
              ],
            ),
          ),
          SwanRing(
            value: s?.rate ?? 0,
            track: line,
            progress: kTeal,
            size: 54,
            stroke: 6,
            center: Text('%${((s?.rate ?? 0) * 100).round()}',
                style: jakarta(11, FontWeight.w800, ink)),
          ),
        ]),
        const SizedBox(height: 14),
        Divider(color: line, height: 1),
        const SizedBox(height: 14),
        Row(children: [
          _stat(ink, 'Tahakkuk', money(s?.billed ?? 0)),
          _stat(ink, 'Kalan', money(s?.outstanding ?? 0)),
          _stat(ink, 'Gecikmiş', money(s?.overdueTotal ?? 0),
              alert: (s?.overdueCount ?? 0) > 0),
        ]),
      ]),
    );
  }

  Widget _stat(Color ink, String label, String value, {bool alert = false}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: jakarta(13.5, FontWeight.w800,
                    alert ? const Color(0xFFF43F5E) : ink)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    jakarta(10.5, FontWeight.w600, SwanColors.textSecondary)),
          ],
        ),
      );

  Widget _feeRow(bool isDark, Color ink, FeeRow f) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final (color, icon) = f.isPaid
        ? (const Color(0xFF10B981), Icons.check_circle_rounded)
        : f.overdue
            ? (const Color(0xFFF43F5E), Icons.error_rounded)
            : (SwanColors.textSecondary, Icons.schedule_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.athleteName ?? 'Sporcu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(13, FontWeight.w800, ink)),
              const SizedBox(height: 2),
              Text(
                  [
                    f.label,
                    if (f.dueDate != null)
                      'Son: ${f.dueDate!.day}.${f.dueDate!.month}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(
                      10.5, FontWeight.w500, SwanColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(f.amount), style: jakarta(13, FontWeight.w800, ink)),
          const SizedBox(height: 2),
          Text(f.statusLabel,
              style: jakarta(10, FontWeight.w700, color)),
        ]),
        if (!f.isPaid) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _collect(f),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Text('Tahsil', style: jakarta(11, FontWeight.w800, kTeal)),
            ),
          ),
        ],
      ]),
    );
  }

  // ------------------------------ 2) ÖDEMELER ------------------------------
  Widget _paymentsTab(bool isDark, Color ink) {
    final pending = ref.watch(pendingPaymentsProvider);
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
      children: [
        Text('Veli havale yapıp "ödedim" dediğinde bildirim buraya düşer. '
            'Dekontu kontrol edip onayladığında borç kapanır.',
            style: jakarta(11.5, FontWeight.w500, SwanColors.textSecondary)),
        const SizedBox(height: 14),
        pending.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? premiumEmpty(
                  context,
                  icon: Icons.inbox_rounded,
                  title: 'Onay bekleyen ödeme yok',
                  subtitle: 'Gelen ödeme bildirimleri burada birikir.',
                )
              : Column(children: [
                  for (final p in list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.athleteName ?? p.label,
                                      style:
                                          jakarta(13, FontWeight.w800, ink)),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${p.label} · ${p.method} · '
                                      '${p.paidAt.day}.${p.paidAt.month}.${p.paidAt.year}',
                                      style: jakarta(10.5, FontWeight.w500,
                                          SwanColors.textSecondary)),
                                  if (p.declaredName != null)
                                    Text('Bildiren: ${p.declaredName}',
                                        style: jakarta(10.5, FontWeight.w500,
                                            SwanColors.textSecondary)),
                                ],
                              ),
                            ),
                            Text(money(p.amount),
                                style: sora(17, FontWeight.w800, ink)),
                          ]),
                          if (p.note != null && p.note!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(p.note!,
                                style: jakarta(11.5, FontWeight.w500,
                                    SwanColors.textSecondary)),
                          ],
                          if (p.receiptUrl != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(p.receiptUrl!,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox
                                      .shrink()),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _confirm(p.id, false),
                                child: Container(
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: line),
                                  ),
                                  child: Text('Reddet',
                                      style: jakarta(12.5, FontWeight.w800,
                                          const Color(0xFFF43F5E))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _confirm(p.id, true),
                                child: Container(
                                  height: 40,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('Onayla',
                                      style: jakarta(
                                          12.5, FontWeight.w800, Colors.white)),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                ]),
        ),
      ],
    );
  }

  // ------------------------------ 3) PLANLAR -------------------------------
  Widget _plansTab(bool isDark, Color ink) {
    final plans = ref.watch(feePlansProvider);
    final athletes = ref.watch(clubAthletesProvider).valueOrNull ?? const [];
    final assigns = ref.watch(feeAssignmentsProvider).valueOrNull ?? const {};
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
      children: [
        Row(children: [
          Text('AİDAT PLANLARI',
              style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                  ls: 1.2)),
          const Spacer(),
          AddButton(tooltip: 'Plan ekle', onTap: _addPlan),
        ]),
        const SizedBox(height: 10),
        plans.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? Text('Henüz plan yok. "Altyapı — aylık 1.500 ₺" gibi bir plan '
                  'tanımlayıp sporculara ata.',
                  style: jakarta(
                      12, FontWeight.w500, SwanColors.textSecondary))
              : Column(children: [
                  for (final p in list)
                    Container(
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: surf,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: line),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: jakarta(13, FontWeight.w800, ink)),
                              Text('Her ayın ${p.dueDay}. günü son ödeme',
                                  style: jakarta(10.5, FontWeight.w500,
                                      SwanColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(money(p.amount),
                            style: jakarta(13.5, FontWeight.w800, kTeal)),
                      ]),
                    ),
                ]),
        ),
        const SizedBox(height: 22),
        Text('SPORCU ATAMALARI',
            style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                ls: 1.2)),
        const SizedBox(height: 4),
        Text('Kişiye özel tutar girersen (burs, kardeş indirimi) plandaki '
            'tutar yerine o geçerli olur. 0 yazarsan borç oluşmaz.',
            style: jakarta(11, FontWeight.w500, SwanColors.textSecondary)),
        const SizedBox(height: 10),
        if (athletes.isEmpty)
          Text('Kadroda sporcu yok.',
              style: jakarta(12, FontWeight.w500, SwanColors.textSecondary))
        else
          Column(children: [
            for (final a in athletes)
              Builder(builder: (_) {
                final asg = assigns[a.id];
                final planName = asg == null
                    ? null
                    : (plans.valueOrNull ?? const <FeePlan>[])
                        .where((p) => p.id == asg.planId)
                        .map((p) => p.name)
                        .firstOrNull;
                return GestureDetector(
                  onTap: () => _assign(a.id, '${a.firstName} ${a.lastName}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surf,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: line),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${a.firstName} ${a.lastName}',
                                style: jakarta(12.5, FontWeight.w700, ink)),
                            Text(
                                asg == null
                                    ? 'Aidat atanmamış'
                                    : [
                                        planName ?? 'Plan',
                                        if (asg.custom != null)
                                          money(asg.custom!),
                                        if (asg.note != null &&
                                            asg.note!.isNotEmpty)
                                          asg.note!,
                                      ].join(' · '),
                                style: jakarta(10.5, FontWeight.w500,
                                    asg == null
                                        ? SwanColors.textSecondary
                                        : kTeal)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: SwanColors.textSecondary),
                    ]),
                  ),
                );
              }),
          ]),
      ],
    );
  }

  Widget _button(bool isDark, IconData icon, String label, VoidCallback onTap,
      {bool subtle = false}) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: subtle
              ? null
              : const LinearGradient(colors: [kTealBright, kTeal]),
          color: subtle ? surf : null,
          borderRadius: BorderRadius.circular(14),
          border: subtle ? Border.all(color: line) : null,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 16, color: subtle ? SwanColors.textSecondary : Colors.white),
          const SizedBox(width: 7),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: jakarta(12, FontWeight.w800,
                    subtle ? SwanColors.textSecondary : Colors.white)),
          ),
        ]),
      ),
    );
  }

  // ------------------------------- eylemler --------------------------------
  Future<void> _guard(Future<void> Function() task, String ok) async {
    try {
      await task();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ok), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }

  Future<void> _generate() async {
    final club = ref.read(activeClubProvider).valueOrNull;
    if (club == null) return;
    try {
      final n =
          await ref.read(financeServiceProvider).generateCharges(club.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(n == 0
                ? 'Yeni borç oluşmadı — bu ay zaten tahakkuk etmiş'
                : '$n sporcuya borç yazıldı'),
            backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Tahakkuk başarısız: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }

  Future<void> _addPlan() async {
    final name = FormField_('Plan adı', hint: 'Altyapı — aylık');
    final amount = FormField_('Aylık tutar (₺)', hint: '1500');
    final day = FormField_('Son ödeme günü', hint: '10', required: false);

    await showQuickForm(
      context,
      title: 'Aidat planı',
      fields: [name, amount, day],
      onSubmit: () => _guard(() async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        await ref.read(financeServiceProvider).createPlan(
              club.id,
              name.value,
              num.tryParse(amount.value.replaceAll(',', '.')) ?? 0,
              dueDay: int.tryParse(day.value) ?? 10,
            );
      }, 'Plan eklendi'),
    );
  }

  Future<void> _assign(String athleteId, String athleteName) async {
    final plans = ref.read(feePlansProvider).valueOrNull ?? const <FeePlan>[];
    if (plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Önce bir aidat planı ekle'),
          backgroundColor: Color(0xFFF43F5E)));
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final planId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(athleteName, style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 14),
          for (final p in plans)
            ListTile(
              title: Text(p.name, style: jakarta(13, FontWeight.w700, ink)),
              subtitle: Text(money(p.amount),
                  style: jakarta(11.5, FontWeight.w600, kTeal)),
              onTap: () => Navigator.pop(ctx, p.id),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFF43F5E)),
            title: Text('Aidatı kaldır',
                style: jakarta(13, FontWeight.w700, const Color(0xFFF43F5E))),
            onTap: () => Navigator.pop(ctx, '__remove__'),
          ),
        ]),
      ),
    );

    if (planId == null) return;
    if (planId == '__remove__') {
      await _guard(
          () => ref.read(financeServiceProvider).removeFee(athleteId),
          'Aidat kaldırıldı');
      ref.invalidate(feeAssignmentsProvider);
      return;
    }

    final custom = FormField_('Kişiye özel tutar (₺)',
        hint: 'Boş bırak = plandaki tutar', required: false);
    final note = FormField_('Not', hint: 'burslu / kardeş indirimi',
        required: false);

    await showQuickForm(
      context,
      title: '$athleteName · aidat',
      fields: [custom, note],
      onSubmit: () async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        await _guard(() async {
          await ref.read(financeServiceProvider).assignFee(
                clubId: club.id,
                athleteId: athleteId,
                planId: planId,
                customAmount: custom.value.trim().isEmpty
                    ? null
                    : num.tryParse(custom.value.replaceAll(',', '.')),
                note: note.value.trim().isEmpty ? null : note.value.trim(),
              );
          ref.invalidate(feeAssignmentsProvider);
        }, 'Aidat atandı');
      },
    );
  }

  Future<void> _addExtra() async {
    final athletes = ref.read(clubAthletesProvider).valueOrNull ?? const [];
    if (athletes.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final athleteId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(children: [
          Text('Kime borç yazılacak?', style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: athletes.length,
              itemBuilder: (_, i) => ListTile(
                title: Text('${athletes[i].firstName} ${athletes[i].lastName}',
                    style: jakarta(13, FontWeight.w600, ink)),
                onTap: () => Navigator.pop(ctx, athletes[i].id),
              ),
            ),
          ),
        ]),
      ),
    );
    if (athleteId == null) return;

    final label = FormField_('Açıklama', hint: 'Turnuva katılım ücreti');
    final amount = FormField_('Tutar (₺)', hint: '750');

    await showQuickForm(
      context,
      title: 'Tek seferlik borç',
      fields: [label, amount],
      onSubmit: () => _guard(() async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        await ref.read(financeServiceProvider).addExtraCharge(
              clubId: club.id,
              athleteId: athleteId,
              label: label.value,
              amount: num.tryParse(amount.value.replaceAll(',', '.')) ?? 0,
            );
      }, 'Borç eklendi'),
    );
  }

  /// Kulüp elden tahsilat girer — onay adımı gerekmez.
  Future<void> _collect(FeeRow f) async {
    final amount = FormField_('Tahsil edilen (₺)', hint: '${f.amount}');
    final note = FormField_('Not', hint: 'nakit / elden', required: false);

    await showQuickForm(
      context,
      title: '${f.athleteName ?? "Sporcu"} · tahsilat',
      fields: [amount, note],
      onSubmit: () => _guard(
        () => ref.read(financeServiceProvider).recordPayment(
              f.invoiceId,
              amount: num.tryParse(amount.value.replaceAll(',', '.')),
              note: note.value.trim().isEmpty ? null : note.value.trim(),
            ),
        'Tahsilat kaydedildi',
      ),
    );
  }

  Future<void> _confirm(String paymentId, bool approve) => _guard(
        () => ref
            .read(financeServiceProvider)
            .confirmPayment(paymentId, approve),
        approve ? 'Ödeme onaylandı' : 'Ödeme reddedildi',
      );

  Future<void> _editBank() async {
    final info = ref.read(clubBankInfoProvider).valueOrNull;
    final holder = FormField_('Hesap sahibi',
        hint: 'Kulüp Derneği', required: false)
      ..controller.text = info?.holder ?? '';
    final bank = FormField_('Banka', hint: 'Ziraat', required: false)
      ..controller.text = info?.bank ?? '';
    final iban = FormField_('IBAN', hint: 'TR..', required: false)
      ..controller.text = info?.iban ?? '';

    await showQuickForm(
      context,
      title: 'Havale bilgileri',
      fields: [holder, bank, iban],
      onSubmit: () => _guard(() async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        await ref.read(financeServiceProvider).setBankInfo(
              club.id,
              iban: iban.value,
              bank: bank.value,
              holder: holder.value,
            );
        ref.invalidate(clubBankInfoProvider);
      }, 'Havale bilgileri kaydedildi'),
    );
  }
}
