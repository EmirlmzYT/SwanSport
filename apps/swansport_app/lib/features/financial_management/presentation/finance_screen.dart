import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'fee_plan_status_switch.dart';

/// Kulüp finansı — aidat tahakkuku, tahsilat onayı ve planlar.
///
/// Stitch "Calm Athletic Modernism" tasarımına uyumlu:
/// - Aidat ve tahsilat özeti Kartı (3 Katmanlı Nakit Akış Göstergesi)
/// - Temel Finansal Metrikler Izgarası (Tahsilat, Sabit Gider, Ekipman Fonu)
/// - Hızlı Mali İşlem Kısayolları (Toplu Hatırlat, Masraf Ekle, Tahakkuk)
/// - Kritik Eylem Bekleyen İşlem Kuyruğu
/// - Borçlar, Ödemeler ve Planlar sekmeleri
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  int _tab = 0; // 0: Borçlar, 1: Ödemeler, 2: Planlar
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
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;
    final club = ref.watch(activeClubProvider).valueOrNull;

    final summaryAsync = ref.watch(financeSummaryProvider);
    final summary = summaryAsync.valueOrNull;
    final pendingCount = summary?.pendingPayments ?? 0;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                _buildHeader(context, palette, club?.name ?? 'Kulüp'),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _refresh();
                      await ref.read(financeSummaryProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [
                        // Live Projection Header Strip
                        _buildProjectionStrip(palette),
                        const SizedBox(height: 12),

                        summaryAsync.when(
                          loading: premiumLoading,
                          error: (e, _) =>
                              premiumError(context, 'Mali özet alınamadı: $e'),
                          data: (value) => Column(children: [
                            _buildCashflowCard(value, palette, isDark),
                            const SizedBox(height: 12),
                            _buildMetricsGrid(value, palette),
                          ]),
                        ),
                        const SizedBox(height: 14),

                        // Quick Financial Actions
                        _buildQuickActions(context, palette),
                        const SizedBox(height: 16),

                        // Action Queue Preview (if any pending)
                        if (pendingCount > 0 ||
                            (summary?.overdueCount ?? 0) > 0)
                          _buildActionQueuePreview(
                            summary,
                            pendingCount,
                            palette,
                          ),

                        const SizedBox(height: 8),

                        // Segmented Tab Switcher
                        _buildTabSwitcher(palette, pendingCount),
                        const SizedBox(height: 14),

                        // Active Tab Content
                        switch (_tab) {
                          1 => _buildPaymentsSection(palette),
                          2 => _buildPlansSection(palette),
                          _ => _buildLedgerSection(palette),
                        },
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

  Widget _buildHeader(
    BuildContext context,
    SwanPalette palette,
    String clubName,
  ) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '$clubName • Finans',
                        style: SwanType.caption(palette.inkMuted),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '₺ TRY',
                          style: SwanType.caption(
                            palette.accent,
                            w: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Finans Merkezi',
                    style: SwanType.h3(palette.ink),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _editBank,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.line),
                  ),
                  child: Icon(
                    Icons.account_balance_rounded,
                    size: 18,
                    color: palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/mali-isler'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: palette.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 18,
                    color: palette.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionStrip(SwanPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Aidat ve tahsilat özeti',
              style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
            ),
          ],
        ),
        GestureDetector(
          onTap: () =>
              setState(() => _period = _period.isEmpty ? _thisPeriod : ''),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(SwanRadius.lg),
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 14,
                  color: palette.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  _period.isEmpty ? 'Tüm Dönemler' : _period,
                  style: SwanType.caption(palette.ink, w: FontWeight.w700),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more_rounded,
                  size: 14,
                  color: palette.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashflowCard(
    FinanceSummary? summary,
    SwanPalette palette,
    bool isDark,
  ) {
    final collected = summary?.collected ?? 0;
    final billed = summary?.billed ?? 0;
    final overdue = summary?.overdueTotal ?? 0;
    final rate = summary?.rate ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kTeal.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: kTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'KULÜP FİNANS ÖZETİ',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: kTeal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tüm dönemlerin aidatları',
                      style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kulüp aidat tahsilat takibi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFFBBC9C7),
                      ),
                    ),
                  ],
                ),
              ),
              SwanRing(
                value: rate,
                track: const Color(0xFF1E2B3C),
                progress: kTeal,
                size: 64,
                stroke: 7,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '%${(rate * 100).round()}',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      'oran',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 8,
                        color: const Color(0xFFBBC9C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2x2 Snapshot KPIs
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.55,
            children: [
              _snapshotTile(
                title: 'Toplam Tahsilat',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: kTeal,
                amount: money(collected),
                subtext: 'Onaylı tahsilatlar',
                subColor: kTeal,
              ),
              _snapshotTile(
                title: 'Toplam Tahakkuk',
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF54DAD1),
                amount: money(billed),
                subtext: 'Tanımlanmış aidatlar',
                subColor: const Color(0xFFBBC9C7),
              ),
              _snapshotTile(
                title: 'Bekleyen Aidat',
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFFFF8C6F),
                amount: money(summary?.outstanding ?? 0),
                subtext: 'Ödenmemiş aidatlar',
                subColor: const Color(0xFFFF8C6F),
              ),
              _snapshotTile(
                title: 'Geciken Ödeme',
                icon: Icons.warning_rounded,
                iconColor: const Color(0xFFFF5252),
                amount: money(overdue),
                subtext: 'Vadesi geçmiş aidatlar',
                subColor: const Color(0xFFFF5252),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _snapshotTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String amount,
    required String subtext,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFBBC9C7),
                ),
              ),
              Icon(icon, size: 14, color: iconColor),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                amount,
                style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(FinanceSummary? summary, SwanPalette palette) {
    final rate = summary?.rate ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.pie_chart_rounded,
            iconColor: palette.accent,
            badge: '%${(rate * 100).round()}',
            title: 'Tahsilat Oranı',
            value: money(summary?.collected ?? 0),
            subtext: 'Bütçelenen',
            palette: palette,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.account_balance_rounded,
            iconColor: Colors.blue,
            badge: 'Aylık',
            title: 'Toplam Tahakkuk',
            value: money(summary?.billed ?? 0),
            subtext: 'Genel Borç',
            palette: palette,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.shield_rounded,
            iconColor: palette.warning,
            badge: 'Kalan',
            title: 'Gecikmiş Tutar',
            value: money(summary?.overdueTotal ?? 0),
            subtext: '${summary?.overdueCount ?? 0} Sporcu',
            palette: palette,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String badge,
    required String title,
    required String value,
    required String subtext,
    required SwanPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: iconColor),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: SwanType.caption(palette.ink, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: SwanType.caption(palette.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtext,
            style: SwanType.caption(palette.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, SwanPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MALİ İŞLEM KISAYOLLARI',
          style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildQuickPill(
                icon: Icons.forward_to_inbox_rounded,
                label: 'Toplu Hatırlat',
                isPrimary: true,
                onTap: () => Navigator.pushNamed(context, '/mali-isler'),
                palette: palette,
              ),
              const SizedBox(width: 8),
              _buildQuickPill(
                icon: Icons.receipt_long_rounded,
                label: 'Masraf Ekle',
                isPrimary: false,
                onTap: () => Navigator.pushNamed(context, '/gider-ekle'),
                palette: palette,
              ),
              const SizedBox(width: 8),
              _buildQuickPill(
                icon: Icons.playlist_add_rounded,
                label: 'Bu Ayı Tahakkuk Ettir',
                isPrimary: false,
                onTap: _generate,
                palette: palette,
              ),
              const SizedBox(width: 8),
              _buildQuickPill(
                icon: Icons.add_circle_outline_rounded,
                label: 'Tek Seferlik Borç',
                isPrimary: false,
                onTap: _addExtra,
                palette: palette,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPill({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
    required SwanPalette palette,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? palette.accent : palette.surface,
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          border: Border.all(
            color: isPrimary ? palette.accent : palette.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : palette.ink,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: SwanType.caption(
                isPrimary ? Colors.white : palette.ink,
                w: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionQueuePreview(
    FinanceSummary? summary,
    int pendingCount,
    SwanPalette palette,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'İşlem Bekleyenler',
                    style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${pendingCount + (summary?.overdueCount ?? 0)}',
                      style: SwanType.caption(Colors.white, w: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/mali-isler'),
                child: Text(
                  'Tümünü Yönet',
                  style: SwanType.caption(palette.accent, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Overdue card item
          if ((summary?.overdueCount ?? 0) > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      size: 16,
                      color: palette.danger,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summary!.overdueCount} Sporcuya Aidat Hatırlatması',
                          style:
                              SwanType.caption(palette.ink, w: FontWeight.w700),
                        ),
                        Text(
                          'Toplam: ${money(summary.overdueTotal)}',
                          style: SwanType.caption(palette.danger),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/mali-isler'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                      ),
                      child: Text(
                        'Hatırlat',
                        style:
                            SwanType.caption(Colors.white, w: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Pending Payments card item
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pending_actions_rounded,
                      size: 16,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$pendingCount Ödeme Onayı Bekliyor',
                          style:
                              SwanType.caption(palette.ink, w: FontWeight.w700),
                        ),
                        Text(
                          'Havale/EFT dekontu incelemesi',
                          style: SwanType.caption(palette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _tab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                        border: Border.all(color: palette.line),
                      ),
                      child: Text(
                        'İncele',
                        style:
                            SwanType.caption(palette.ink, w: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(SwanPalette palette, int pendingCount) {
    final tabs = [
      ('Borçlar', 0),
      ('Ödemeler ($pendingCount)', pendingCount),
      ('Planlar', 0),
    ];

    return Row(
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _tab == i ? palette.accent : palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _tab == i ? palette.accent : palette.line,
                  ),
                ),
                child: Center(
                  child: Text(
                    tabs[i].$1,
                    style: SwanType.caption(
                      _tab == i ? Colors.white : palette.inkMuted,
                      w: _tab == i ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ------------------------- TAB 0: BORÇLAR -------------------------
  Widget _buildLedgerSection(SwanPalette palette) {
    final ledger = ref.watch(feeLedgerProvider(_period));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Borç Listesi',
              style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            ),
            Text(
              _period.isEmpty ? 'Tüm Kayıtlar' : _period,
              style: SwanType.caption(palette.accent, w: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ledger.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border.all(color: palette.line),
                  ),
                  child: Center(
                    child: Text(
                      'Bu dönem için borç kaydı yok.\nYukarıdaki "Tahakkuk Ettir" ile yeni aidatları oluşturabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: SwanType.caption(palette.inkMuted),
                    ),
                  ),
                )
              : Column(
                  children: [for (final f in list) _buildFeeCard(f, palette)],
                ),
        ),
      ],
    );
  }

  Widget _buildFeeCard(FeeRow f, SwanPalette palette) {
    final (color, icon) = f.isPaid
        ? (palette.success, Icons.check_circle_rounded)
        : f.overdue
            ? (palette.danger, Icons.error_rounded)
            : (palette.inkMuted, Icons.schedule_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.athleteName ?? 'Sporcu',
                  style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    f.label,
                    if (f.dueDate != null)
                      'Son: ${f.dueDate!.day}.${f.dueDate!.month}',
                  ].join(' · '),
                  style: SwanType.caption(palette.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(f.amount),
                style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                f.statusLabel,
                style: SwanType.caption(color, w: FontWeight.w700),
              ),
            ],
          ),
          if (!f.isPaid) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _collect(f),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Tahsil',
                  style: SwanType.caption(palette.accent, w: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------- TAB 1: ÖDEMELER -------------------------
  Widget _buildPaymentsSection(SwanPalette palette) {
    final pending = ref.watch(pendingPaymentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Onay Bekleyen Bildirimler',
          style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Veli havale/FAST dekontu yüklediğinde buraya düşer. İnceleyip onaylayabilirsiniz.',
          style: SwanType.caption(palette.inkMuted),
        ),
        const SizedBox(height: 10),
        pending.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border.all(color: palette.line),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 38,
                          color: palette.inkMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Onay bekleyen ödeme yok',
                          style:
                              SwanType.bodySm(palette.ink, w: FontWeight.w700),
                        ),
                        Text(
                          'Gelen ödeme bildirimleri burada toplanır.',
                          style: SwanType.caption(palette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final p in list) _buildPaymentCard(p, palette),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(PendingPayment p, SwanPalette palette) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.athleteName ?? p.label,
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.label} · ${p.method} · ${p.paidAt.day}.${p.paidAt.month}.${p.paidAt.year}',
                      style: SwanType.caption(palette.inkMuted),
                    ),
                    if (p.declaredName != null)
                      Text(
                        'Bildiren: ${p.declaredName}',
                        style: SwanType.caption(palette.inkMuted),
                      ),
                  ],
                ),
              ),
              Text(money(p.amount), style: SwanType.h3(palette.accent)),
            ],
          ),
          if (p.note != null && p.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                p.note!,
                style: SwanType.caption(palette.ink),
              ),
            ),
          ],
          if (p.receiptUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                p.receiptUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _confirm(p.id, false),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.line),
                    ),
                    child: Text(
                      'Reddet',
                      style: SwanType.caption(
                        palette.danger,
                        w: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _confirm(p.id, true),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Onayla ve Kapat',
                      style: SwanType.caption(
                        Colors.white,
                        w: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------- TAB 2: PLANLAR -------------------------
  Widget _buildPlansSection(SwanPalette palette) {
    final plans = ref.watch(feePlansProvider);
    final athletes = ref.watch(clubAthletesProvider).valueOrNull ?? const [];
    final assigns = ref.watch(feeAssignmentsProvider).valueOrNull ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aidat Planları',
              style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            ),
            GestureDetector(
              onTap: _addPlan,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Plan Ekle',
                      style: SwanType.caption(
                        Colors.white,
                        w: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        plans.when(
          loading: premiumLoading,
          error: (e, _) => premiumError(context, '$e'),
          data: (list) => list.isEmpty
              ? Text(
                  'Henüz aidat planı oluşturulmadı.',
                  style: SwanType.caption(palette.inkMuted),
                )
              : Column(
                  children: [
                    for (final p in list)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          border: Border.all(color: palette.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    style: SwanType.bodySm(
                                      palette.ink,
                                      w: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${p.active ? 'Aktif' : 'Pasif taslak'} · Her ayın ${p.dueDay}. günü son ödeme',
                                    style: SwanType.caption(palette.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              money(p.amount),
                              style: SwanType.bodySm(
                                palette.accent,
                                w: FontWeight.w700,
                              ),
                            ),
                            FeePlanStatusSwitch(plan: p),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        Text(
          'Sporcu Atamaları',
          style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          'Sporculara özel indirim (burs, kardeş) tanımı yapılabilir.',
          style: SwanType.caption(palette.inkMuted),
        ),
        const SizedBox(height: 10),
        if (athletes.isEmpty)
          Text(
            'Kadroda sporcu yok.',
            style: SwanType.caption(palette.inkMuted),
          )
        else
          Column(
            children: [
              for (final a in athletes)
                Builder(
                  builder: (_) {
                    final asg = assigns[a.id];
                    final planName = asg == null
                        ? null
                        : (plans.valueOrNull ?? const <FeePlan>[])
                            .where((p) => p.id == asg.planId)
                            .map((p) => p.name)
                            .firstOrNull;

                    return GestureDetector(
                      onTap: () =>
                          _assign(a.id, '${a.firstName} ${a.lastName}'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          border: Border.all(color: palette.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${a.firstName} ${a.lastName}',
                                    style: SwanType.caption(
                                      palette.ink,
                                      w: FontWeight.w700,
                                    ),
                                  ),
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
                                    style: SwanType.caption(
                                      asg == null
                                          ? palette.inkMuted
                                          : palette.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: palette.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }

  // ------------------------- EYLEMLER -------------------------
  Future<void> _guard(Future<void> Function() task, String ok) async {
    try {
      await task();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok), backgroundColor: kTeal),
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
  }

  Future<void> _generate() async {
    final club = ref.read(activeClubProvider).valueOrNull;
    if (club == null) return;
    try {
      final n = await ref.read(financeServiceProvider).generateCharges(club.id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              n == 0
                  ? 'Yeni borç oluşmadı — bu ay zaten tahakkuk etmiş'
                  : '$n sporcuya borç yazıldı',
            ),
            backgroundColor: kTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tahakkuk başarısız: $e'),
            backgroundColor: SwanPalette.light.danger,
          ),
        );
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
      onSubmit: () => _guard(
        () async {
          final club = ref.read(activeClubProvider).valueOrNull;
          if (club == null) return;
          await ref.read(financeServiceProvider).createPlan(
                club.id,
                name.value,
                num.tryParse(amount.value.replaceAll(',', '.')) ?? 0,
                dueDay: int.tryParse(day.value) ?? 10,
              );
        },
        'Plan eklendi',
      ),
    );
  }

  Future<void> _assign(String athleteId, String athleteName) async {
    final plans = (ref.read(feePlansProvider).valueOrNull ?? const <FeePlan>[])
        .where((p) => p.active)
        .toList();
    final hasAssignment =
        ref.read(feeAssignmentsProvider).valueOrNull?.containsKey(athleteId) ??
            false;
    if (plans.isEmpty && !hasAssignment) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Önce bir aidat planı ekle veya taslak planı etkinleştir'),
          backgroundColor: SwanPalette.light.danger,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final planId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(athleteName, style: SwanType.h3(ink)),
            const SizedBox(height: 14),
            for (final p in plans)
              ListTile(
                title: Text(
                  p.name,
                  style: SwanType.bodySm(ink, w: FontWeight.w700),
                ),
                subtitle: Text(
                  money(p.amount),
                  style: SwanType.caption(kTeal, w: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, p.id),
              ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: SwanPalette.light.danger,
              ),
              title: Text(
                'Aidatı kaldır',
                style: SwanType.bodySm(
                  SwanPalette.light.danger,
                  w: FontWeight.w700,
                ),
              ),
              onTap: () => Navigator.pop(ctx, '__remove__'),
            ),
          ],
        ),
      ),
    );

    if (planId == null) return;
    if (planId == '__remove__') {
      await _guard(
        () => ref.read(financeServiceProvider).removeFee(athleteId),
        'Aidat kaldırıldı',
      );
      ref.invalidate(feeAssignmentsProvider);
      return;
    }

    final custom = FormField_(
      'Kişiye özel tutar (₺)',
      hint: 'Boş bırak = plandaki tutar',
      required: false,
    );
    final note =
        FormField_('Not', hint: 'burslu / kardeş indirimi', required: false);

    if (!mounted) return;
    await showQuickForm(
      context,
      title: '$athleteName · aidat',
      fields: [custom, note],
      onSubmit: () async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        await _guard(
          () async {
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
          },
          'Aidat atandı',
        );
      },
    );
  }

  Future<void> _addExtra() async {
    final athletes = ref.read(clubAthletesProvider).valueOrNull ?? const [];
    if (athletes.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

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
        padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 18, SwanSpace.lg, 10),
        child: Column(
          children: [
            Text('Kime borç yazılacak?', style: SwanType.h3(ink)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: athletes.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(
                    '${athletes[i].firstName} ${athletes[i].lastName}',
                    style: SwanType.bodySm(ink, w: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(ctx, athletes[i].id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (athleteId == null) return;

    final label = FormField_('Açıklama', hint: 'Turnuva katılım ücreti');
    final amount = FormField_('Tutar (₺)', hint: '750');

    if (!mounted) return;
    await showQuickForm(
      context,
      title: 'Tek seferlik borç',
      fields: [label, amount],
      onSubmit: () => _guard(
        () async {
          final club = ref.read(activeClubProvider).valueOrNull;
          if (club == null) return;
          await ref.read(financeServiceProvider).addExtraCharge(
                clubId: club.id,
                athleteId: athleteId,
                label: label.value,
                amount: num.tryParse(amount.value.replaceAll(',', '.')) ?? 0,
              );
        },
        'Borç eklendi',
      ),
    );
  }

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
        () =>
            ref.read(financeServiceProvider).confirmPayment(paymentId, approve),
        approve ? 'Ödeme onaylandı' : 'Ödeme reddedildi',
      );

  Future<void> _editBank() async {
    final info = ref.read(clubBankInfoProvider).valueOrNull;
    final holder =
        FormField_('Hesap sahibi', hint: 'Kulüp Derneği', required: false)
          ..controller.text = info?.holder ?? '';
    final bank = FormField_('Banka', hint: 'Ziraat', required: false)
      ..controller.text = info?.bank ?? '';
    final iban = FormField_('IBAN', hint: 'TR..', required: false)
      ..controller.text = info?.iban ?? '';

    await showQuickForm(
      context,
      title: 'Havale bilgileri',
      fields: [holder, bank, iban],
      onSubmit: () => _guard(
        () async {
          final club = ref.read(activeClubProvider).valueOrNull;
          if (club == null) return;
          await ref.read(financeServiceProvider).setBankInfo(
                club.id,
                iban: iban.value,
                bank: bank.value,
                holder: holder.value,
              );
          ref.invalidate(clubBankInfoProvider);
        },
        'Havale bilgileri kaydedildi',
      ),
    );
  }
}
