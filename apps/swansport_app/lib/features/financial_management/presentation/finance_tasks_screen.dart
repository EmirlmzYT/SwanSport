import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Mali işler — mobil operasyon ve aidat görev kuyruğu.
///
/// Stitch "Calm Athletic Modernism" (aidat_g_rev_kuyru_u_ve_takip) tasarımına uyumlu:
/// - Arama ve Hızlı Filtre Hapları (Tümü, Gecikmiş, Vadesi Yaklaşan, Onay Bekleyen)
/// - Kritik Taktiksel Risk Özeti (Toplam Risk, Toplu Hatırlatma Butonu)
/// - Aidat Görev Listesi ve Sporcu Kartları
/// - Gider Onayı Kuyruğu (Hızlı Onayla / Gerekçeli Reddet)
class FinanceTasksScreen extends ConsumerStatefulWidget {
  const FinanceTasksScreen({super.key});

  @override
  ConsumerState<FinanceTasksScreen> createState() => _FinanceTasksScreenState();
}

class _FinanceTasksScreenState extends ConsumerState<FinanceTasksScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all | overdue | upcoming | pending
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;

    final summaryAsync = ref.watch(financeOperationsSummaryProvider);
    final approvalsAsync = ref.watch(pendingApprovalsProvider);
    final ledgerAsync = ref.watch(feeLedgerProvider(''));

    final ledger = ledgerAsync.valueOrNull ?? const <FeeRow>[];
    final overdueList = ledger.where((f) => !f.isPaid && f.overdue).toList();
    final totalOverdueAmount = overdueList.fold<num>(
      0,
      (sum, item) => sum + item.amount,
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _buildHeader(context, palette),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(financeOperationsSummaryProvider);
                      ref.invalidate(pendingApprovalsProvider);
                      ref.invalidate(feeLedgerProvider(''));
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [
                        // Search and Filter Pills
                        _buildSearchAndFilters(palette, overdueList.length),
                        const SizedBox(height: 12),

                        // Summary Alert Banner: High-Touch Tactical Callout
                        if (overdueList.isNotEmpty)
                          _buildRiskBanner(
                            overdueCount: overdueList.length,
                            totalRisk: totalOverdueAmount,
                            palette: palette,
                            isDark: isDark,
                          ),
                        if (overdueList.isNotEmpty) const SizedBox(height: 14),

                        // Section 1: Pending Expense Approvals (Gider Onayları)
                        approvalsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (approvals) {
                            if (approvals.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.assignment_turned_in_rounded,
                                          size: 18,
                                          color: palette.accent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Onay Bekleyen Masraflar',
                                          style: SwanType.bodySm(
                                            palette.ink,
                                            w: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.accent
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${approvals.length} Talep',
                                        style: SwanType.caption(
                                          palette.accent,
                                          w: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kendi girdiğin gider burada çıkmaz — kimse kendi kaydını onaylayamıyor.',
                                  style: SwanType.caption(palette.inkMuted),
                                ),
                                const SizedBox(height: 10),
                                for (final exp in approvals)
                                  _ApprovalTile(expense: exp, palette: palette),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),

                        // Section 2: Operations Work Summary
                        summaryAsync.when(
                          loading: premiumLoading,
                          error: (e, _) => premiumError(context, '$e'),
                          data: (summary) {
                            if (summary.items.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Operasyon Durum Raporu',
                                  style: SwanType.bodySm(
                                    palette.ink,
                                    w: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final item in summary.topItems)
                                  _buildSummaryWorkItem(item, palette),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),

                        // Section 3: Task & Athlete Fee List (Aidat Görev Listesi)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Aidat Görev Listesi',
                                  style: SwanType.bodySm(
                                    palette.ink,
                                    w: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.surfaceAlt,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${ledger.length} Kayıt',
                                    style: SwanType.caption(
                                      palette.inkMuted,
                                      w: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Filtered Ledger / Tasks
                        _buildFeeTaskList(ledger, palette),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(BuildContext context, SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: palette.line.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.line),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mali İşler & Görevler',
                    style: SwanType.h3(palette.ink),
                  ),
                  Text(
                    'Bekleyen İşler ve Gider Onayları',
                    style: SwanType.caption(palette.accent, w: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(SwanPalette palette, int overdueCount) {
    return Column(
      children: [
        // Search Bar Input
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: palette.inkMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: SwanType.bodySm(palette.ink),
                  decoration: InputDecoration(
                    hintText: 'Sporcu adı veya açıklama ara...',
                    hintStyle: SwanType.caption(palette.inkMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 16,
                    color: palette.inkMuted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Filter Pills Carousel
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterPill(
                key: 'all',
                label: 'Tümü',
                palette: palette,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                key: 'overdue',
                label: 'Gecikmiş ($overdueCount)',
                palette: palette,
                highlightDanger: overdueCount > 0,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                key: 'upcoming',
                label: 'Vadesi Yaklaşan',
                palette: palette,
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                key: 'pending',
                label: 'Onay Bekleyen',
                palette: palette,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill({
    required String key,
    required String label,
    required SwanPalette palette,
    bool highlightDanger = false,
  }) {
    final isSelected = _selectedFilter == key;
    final bg = isSelected
        ? palette.accent
        : highlightDanger
            ? palette.danger.withValues(alpha: 0.1)
            : palette.surface;
    final textColor = isSelected
        ? Colors.white
        : highlightDanger
            ? palette.danger
            : palette.inkMuted;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? palette.accent : palette.line,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: SwanType.caption(
              textColor,
              w: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRiskBanner({
    required int overdueCount,
    required num totalRisk,
    required SwanPalette palette,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.danger.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.danger.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: palette.danger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$overdueCount Gecikmiş Aidat',
                            style: SwanType.bodySm(
                              palette.ink,
                              w: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: palette.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kritik tahsilat kuyruğu',
                        style: SwanType.caption(palette.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Toplam Risk',
                    style: SwanType.caption(palette.inkMuted),
                  ),
                  Text(
                    money(totalRisk),
                    style: SwanType.h3(palette.danger),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _remindAll,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: palette.accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.send_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tüm Gecikenlere SMS / Push Hatırlat',
                    style: SwanType.caption(Colors.white, w: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryWorkItem(FinanceWorkItem item, SwanPalette palette) {
    final tone = switch (item.risk) {
      FinanceRisk.critical => palette.danger,
      FinanceRisk.attention => palette.warning,
      FinanceRisk.info => palette.inkMuted,
    };
    final label = switch (item.risk) {
      FinanceRisk.critical => 'Kritik',
      FinanceRisk.attention => 'Dikkat',
      FinanceRisk.info => 'Bilgi',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: SwanType.caption(tone, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.count} Kayıt',
                style: SwanType.caption(palette.inkMuted),
              ),
              if (item.hasTotal)
                Text(
                  fmtMoney(item.total),
                  style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.why,
            style: SwanType.caption(palette.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeTaskList(List<FeeRow> allFees, SwanPalette palette) {
    var filtered = allFees.where((f) {
      if (_selectedFilter == 'overdue') return !f.isPaid && f.overdue;
      if (_selectedFilter == 'upcoming') return !f.isPaid && !f.overdue;
      if (_selectedFilter == 'pending') return !f.isPaid;
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((f) {
        final name = (f.athleteName ?? '').toLowerCase();
        final label = f.label.toLowerCase();
        return name.contains(q) || label.contains(q);
      }).toList();
    }

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        child: Center(
          child: Text(
            'Bu filtreye uygun aidat görevi bulunamadı.',
            style: SwanType.caption(palette.inkMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final f in filtered) _buildAthleteTaskCard(f, palette),
      ],
    );
  }

  Widget _buildAthleteTaskCard(FeeRow f, SwanPalette palette) {
    final (statusLabel, statusBg, statusColor) = f.isPaid
        ? (
            'Ödendi',
            palette.success.withValues(alpha: 0.12),
            palette.success,
          )
        : f.overdue
            ? (
                'Gecikti',
                palette.danger.withValues(alpha: 0.12),
                palette.danger,
              )
            : (
                'Vadesi Yaklaşan',
                palette.warning.withValues(alpha: 0.12),
                palette.warning,
              );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: f.overdue ? palette.danger.withValues(alpha: 0.3) : palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (f.athleteName ?? 'SP').substring(0, 1).toUpperCase(),
                        style: SwanType.caption(palette.ink, w: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.athleteName ?? 'Sporcu',
                        style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                      ),
                      Text(
                        f.label,
                        style: SwanType.caption(palette.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: SwanType.caption(statusColor, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Financial detail line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 14,
                      color: palette.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      f.dueDate != null
                          ? 'Vade: ${f.dueDate!.day}.${f.dueDate!.month}.${f.dueDate!.year}'
                          : 'Dönemlik Aidat',
                      style: SwanType.caption(palette.inkMuted),
                    ),
                  ],
                ),
                Text(
                  money(f.amount),
                  style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                ),
              ],
            ),
          ),

          if (!f.isPaid) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _sendReminder(f),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            size: 15,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Hatırlatma Gönder',
                            style: SwanType.caption(
                              palette.accent,
                              w: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _collectDebt(f),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Tahsil Et',
                        style: SwanType.caption(
                          palette.ink,
                          w: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _remindAll() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tüm geciken sporcu ve velilere bildirim gönderildi.'),
        backgroundColor: kTeal,
      ),
    );
  }

  void _sendReminder(FeeRow f) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${f.athleteName ?? "Sporcu"} için hatırlatma iletildi.'),
        backgroundColor: kTeal,
      ),
    );
  }

  void _collectDebt(FeeRow f) async {
    final amount = FormField_('Tahsil edilen (₺)', hint: '${f.amount}');
    final note = FormField_('Not', hint: 'nakit / elden', required: false);

    await showQuickForm(
      context,
      title: '${f.athleteName ?? "Sporcu"} · tahsilat',
      fields: [amount, note],
      onSubmit: () async {
        try {
          await ref.read(financeServiceProvider).recordPayment(
                f.invoiceId,
                amount: num.tryParse(amount.value.replaceAll(',', '.')),
                note: note.value.trim().isEmpty ? null : note.value.trim(),
              );
          ref.invalidate(feeLedgerProvider(''));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tahsilat kaydedildi'),
                backgroundColor: kTeal,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('İşlem başarısız: $e'),
                backgroundColor: SwanPalette.light.danger,
              ),
            );
          }
        }
      },
    );
  }
}

class _ApprovalTile extends ConsumerStatefulWidget {
  const _ApprovalTile({
    required this.expense,
    required this.palette,
  });

  final ExpenseRow expense;
  final SwanPalette palette;

  @override
  ConsumerState<_ApprovalTile> createState() => _ApprovalTileState();
}

class _ApprovalTileState extends ConsumerState<_ApprovalTile> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    String? reason;
    if (!approve) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: widget.palette.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    final palette = widget.palette;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [e.categoryName, e.supplier]
                      .where((x) => (x ?? '').isNotEmpty)
                      .join(' · '),
                  style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmtDate(e.spentOn)} · ${fmtMoney(e.amount)}',
                  style: SwanType.caption(palette.inkMuted),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            GestureDetector(
              onTap: () => _decide(false),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text('Reddet', style: SwanType.caption(palette.danger)),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _decide(true),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Onayla',
                  style: SwanType.caption(Colors.white, w: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
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
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: _c.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _c.text.trim()),
            child: const Text('Reddet'),
          ),
        ],
      );
}
