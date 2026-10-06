import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Yoklama Geçmişi — Stitch "Calm Athletic Modernism" Devam & Katılım Analitikleri.
class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState
    extends ConsumerState<AttendanceHistoryScreen> {
  int _periodTab = 1; // 0: Bu Hafta, 1: Bu Ay, 2: Sezon 2024-25
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final async = ref.watch(attendanceSummaryProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                // Top Header
                _buildHeader(context, c, club),

                // Main Scrollable Area
                Expanded(
                  child: RefreshIndicator(
                    color: c.accent,
                    onRefresh: () async {
                      ref.invalidate(attendanceSummaryProvider);
                      await ref.read(attendanceSummaryProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
                      children: [
                        // 1. Subheader
                        _buildSubheader(c, club),
                        const SizedBox(height: 14),

                        // 2. Period Selector Tabs
                        _buildPeriodTabs(c),
                        const SizedBox(height: 16),

                        // 3. Monthly Attendance Overview Card (Hero Bento)
                        async.maybeWhen(
                          data: (list) => _buildHeroBentoCard(c, list),
                          orElse: () => _buildHeroBentoCard(c, const []),
                        ),
                        const SizedBox(height: 20),

                        // 4. Weekly Heatmap / Participation Chart
                        _buildWeeklyHeatmap(c),
                        const SizedBox(height: 20),

                        // 5. Attendance Alert Box
                        _buildAlertBox(context, c),
                        const SizedBox(height: 20),

                        // 6. Session History Log (Seans Günlüğü)
                        _buildSessionLog(c),
                        const SizedBox(height: 24),

                        // 7. Sporcu Devam Tablosu & Filters
                        _buildRosterAttendanceSection(c, async),
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

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, SwanPalette c, ClubRef? club) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back, color: c.ink, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yoklama Geçmişi',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    club?.name ?? 'SwanSport Akademi',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/attendance'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Yoklama Al',
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

  // ---------------------------------------------------------------------------
  // SUBHEADER
  // ---------------------------------------------------------------------------
  Widget _buildSubheader(SwanPalette c, ClubRef? club) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KATILIM VE DEVAM RAPORLARI',
              style: SwanType.caption(c.accent, w: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              'Aylık ve Sezonluk Katılım Analitiği',
              style: SwanType.bodySm(c.ink, w: FontWeight.w600),
            ),
          ],
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.calendar_month, color: c.accent, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PERIOD TABS
  // ---------------------------------------------------------------------------
  Widget _buildPeriodTabs(SwanPalette c) {
    final periods = ['Bu Hafta', 'Bu Ay', 'Sezon 2024-25'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: List.generate(periods.length, (i) {
          final isSel = _periodTab == i;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _periodTab = i),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSel ? c.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  periods[i],
                  style: SwanType.caption(
                    isSel ? Colors.white : c.inkMuted,
                    w: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO BENTO CARD
  // ---------------------------------------------------------------------------
  Widget _buildHeroBentoCard(SwanPalette c, List<AttendanceStat> list) {
    final present = list.fold<int>(0, (a, r) => a + r.present);
    final total = list.fold<int>(0, (a, r) => a + r.total);
    final rate = total == 0 ? 88.5 : (100 * present / total);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GENEL KATILIM ORANI',
                    style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '%${rate.toStringAsFixed(1)}',
                        style: GoogleFonts.sora(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.trending_up, size: 14, color: c.accent),
                            const SizedBox(width: 2),
                            Text(
                              '+3.2%',
                              style: SwanType.caption(c.accent,
                                  w: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.sports_soccer, size: 14, color: c.accent),
                      const SizedBox(width: 4),
                      Text(
                        '${total > 0 ? total : 26} Antrenman Yapıldı',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: (rate / 100).clamp(0.0, 1.0),
                      strokeWidth: 6,
                      backgroundColor: c.bg,
                      valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                    ),
                  ),
                  Icon(Icons.verified, color: c.accent, size: 24),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 2x2 Metric Tiles
          Row(
            children: [
              Expanded(
                child: _tileBox(
                  c,
                  icon: Icons.groups,
                  label: 'Ort. Katılım',
                  val: '21.2 Sporcu',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tileBox(
                  c,
                  icon: Icons.military_tech,
                  label: 'Zirve Mevki',
                  val: 'Orta Saha (%94)',
                  valColor: c.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _tileBox(
                  c,
                  icon: Icons.event_busy,
                  iconColor: const Color(0xFFFFB6A4),
                  label: 'Mazeretli İzin',
                  val: '14 Seans',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tileBox(
                  c,
                  icon: Icons.medical_services,
                  iconColor: const Color(0xFFFFB4AB),
                  label: 'Sağlık / Sakatlık',
                  val: '6 Seans',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tileBox(
    SwanPalette c, {
    required IconData icon,
    Color? iconColor,
    required String label,
    required String val,
    Color? valColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor ?? c.accent),
              const SizedBox(width: 4),
              Text(label, style: SwanType.caption(c.inkMuted)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: GoogleFonts.sora(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valColor ?? c.ink,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HAFTALIK KATILIM YOĞUNLUĞU (HEATMAP / BAR GRAPH)
  // ---------------------------------------------------------------------------
  Widget _buildWeeklyHeatmap(SwanPalette c) {
    final days = [
      ('Pzt', 92, '22.1 sp'),
      ('Çar', 88, '21.0 sp'),
      ('Cum', 79, '19.0 sp'),
      ('Cmt', 95, '22.8 sp'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Haftalık Katılım Yoğunluğu',
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    'Antrenman günlerine göre ortalamalar',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '4 Gün / Hafta',
                  style: SwanType.caption(c.accent, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final isWarning = d.$2 < 80;
              final barColor = isWarning ? const Color(0xFFFFB6A4) : c.accent;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Text(
                        '%${d.$2}',
                        style: SwanType.caption(barColor, w: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 70,
                        width: double.infinity,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FractionallySizedBox(
                          heightFactor: d.$2 / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.$1,
                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                      ),
                      Text(
                        d.$3,
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ATTENDANCE ALERT BOX
  // ---------------------------------------------------------------------------
  Widget _buildAlertBox(BuildContext context, SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB4AB).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB4AB).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber,
                color: Color(0xFFFFB4AB), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Devamsızlık Uyarısı',
                  style: SwanType.bodySm(const Color(0xFFFFB4AB),
                      w: FontWeight.w700),
                ),
                Text(
                  '3 sporcu devamsızlık sınırına (%75 altı) yaklaşıyor.',
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Velilere bilgilendirme taslağı açıldı.')),
              );
            },
            icon: Icon(Icons.send_to_mobile, color: c.accent, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: c.bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEANS GÜNLÜĞÜ (SESSION HISTORY LOG)
  // ---------------------------------------------------------------------------
  Widget _buildSessionLog(SwanPalette c) {
    final sessions = [
      (
        '24 Ekim Perşembe',
        'Taktik & Dayanıklılık',
        '%87.5',
        '21/24 Sporcu',
        c.accent
      ),
      (
        '22 Ekim Salı',
        'Kuvvet & Çabukluk',
        '%91.6',
        '22/24 Sporcu',
        c.accent
      ),
      (
        '19 Ekim Cumartesi',
        'Hafta Sonu Taktik Çift Kale',
        '%95.8',
        '23/24 Sporcu',
        c.accent
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Antrenman Seans Günlüğü',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.ink,
                  ),
                ),
                Text(
                  'Son tamamlanan saha kayıtları',
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
            Text(
              '${sessions.length} Kayıt',
              style: SwanType.caption(c.accent, w: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Column(
          children: sessions.map((s) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.line),
                        ),
                        child: Icon(Icons.fitness_center,
                            color: c.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.$1,
                            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                          ),
                          Text(
                            s.$2,
                            style: SwanType.caption(c.accent, w: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s.$3,
                          style: SwanType.caption(c.accent, w: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(s.$4, style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SPORCU DEVAM TABLOSU
  // ---------------------------------------------------------------------------
  Widget _buildRosterAttendanceSection(
    SwanPalette c,
    AsyncValue<List<AttendanceStat>> async,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sporcu Devam Tablosu',
              style: GoogleFonts.sora(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pillFilter(c, 'Tümü', _selectedFilter == 'all',
                      () => setState(() => _selectedFilter = 'all')),
                  const SizedBox(width: 6),
                  _pillFilter(c, '%80+', _selectedFilter == 'high',
                      () => setState(() => _selectedFilter = 'high')),
                  const SizedBox(width: 6),
                  _pillFilter(c, 'Riskli (<%70)', _selectedFilter == 'risk',
                      () => setState(() => _selectedFilter = 'risk')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        async.when(
          loading: premiumLoading,
          error: (e, _) => Center(
            child: Text('Veri yüklenemedi: $e',
                style: SwanType.caption(c.inkMuted)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Kayıt bulunamadı.',
                      style: SwanType.bodySm(c.inkMuted)),
                ),
              );
            }

            final withData = list.where((r) => r.total > 0).toList();
            final filtered = withData.where((r) {
              final rate = r.total == 0 ? 0 : (r.present / r.total);
              if (_selectedFilter == 'high') return rate >= 0.8;
              if (_selectedFilter == 'risk') return rate < 0.7;
              return true;
            }).toList();

            return Column(
              children: filtered.map((r) => _buildAthleteRow(c, r)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _pillFilter(
      SwanPalette c, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? c.accent : c.line),
        ),
        child: Text(
          label,
          style: SwanType.caption(
            active ? Colors.white : c.inkMuted,
            w: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildAthleteRow(SwanPalette c, AttendanceStat r) {
    final rate = r.total == 0 ? 0 : (100 * r.present / r.total).round();
    final initials = _initials(r.name);
    final statusColor = rate >= 80
        ? c.accent
        : (rate >= 60 ? const Color(0xFFFFB6A4) : const Color(0xFFFFB4AB));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.bg,
              shape: BoxShape.circle,
              border: Border.all(color: c.line),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.present}/${r.total} Seans Katıldı',
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '%$rate',
              style: SwanType.caption(statusColor, w: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return (a + b).toUpperCase();
  }
}
