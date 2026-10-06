import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Performans — kulüp kadrosunun test ve gelişim durumu & Biyometrik Kokpit.
class PerformanceAnalyticsScreen extends ConsumerStatefulWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  ConsumerState<PerformanceAnalyticsScreen> createState() =>
      _PerformanceAnalyticsScreenState();
}

class _PerformanceAnalyticsScreenState
    extends ConsumerState<PerformanceAnalyticsScreen> {
  final _searchCtrl = TextEditingController();
  String _filter = '';
  String _timeRange = '7d'; // '7d', 'month', 'season'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final async = ref.watch(performanceOverviewProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(performanceOverviewProvider);
                await ref.read(performanceOverviewProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                children: [
                  _buildHeader(context, ink, surf, line, club?.name),
                  const SizedBox(height: 14),

                  // Stitch Time Range Selector
                  _buildTimeRangeTabs(surf, line, ink),
                  const SizedBox(height: 14),

                  // Hero Athletic Index Card
                  _buildHeroAthleticCard(surf, line, ink),
                  const SizedBox(height: 14),

                  // 2x2 Biometrics Grid
                  _buildBiometricsGrid(surf, line, ink),
                  const SizedBox(height: 14),

                  // Weekly Volume vs Intensity Chart
                  _buildVolumeIntensityChart(surf, line, ink),
                  const SizedBox(height: 14),

                  // Heart Rate Zone Breakdown
                  _buildHeartRateZoneCard(surf, line, ink),
                  const SizedBox(height: 14),

                  // SwanAI Coach Note
                  _buildSwanAiCoachCard(surf, line, ink),
                  const SizedBox(height: 14),

                  // BLE Sensor Floating Bar
                  _buildBleSensorBar(surf, line, ink),
                  const SizedBox(height: 14),

                  // Quick Action Shortcuts (Hazırbulunuşluk & Ekipman)
                  _buildQuickModulesBar(context, surf, line, ink),
                  const SizedBox(height: 14),

                  // Search Field
                  _buildSearchBox(surf, line, ink),
                  const SizedBox(height: 14),

                  async.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (rows) {
                      if (rows.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.bar_chart_rounded,
                          title: 'Kadro boş',
                          subtitle:
                              'Sporcu ekledikten sonra test ve gelişim '
                              'hedeflerini buradan takip edersin.',
                        );
                      }

                      final filtered = _filter.isEmpty
                          ? rows
                          : rows
                              .where(
                                (r) => r.name.toLowerCase().contains(
                                      _filter.toLowerCase(),
                                    ),
                              )
                              .toList();

                      final withTests =
                          rows.where((r) => r.tests > 0).length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summary(
                            isDark,
                            ink,
                            rows.length,
                            withTests,
                            rows,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Kadro Sporcuları',
                                style: SwanType.h3(ink),
                              ),
                              Text(
                                '${filtered.length} sporcu',
                                style: SwanType.caption(
                                  SwanColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final r in filtered)
                            _row(context, isDark, ink, r),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color ink,
    Color surf,
    Color line,
    String? clubName,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName ?? 'SwanSport',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
                Text('Performans & Analiz', style: SwanType.h2(ink)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none_rounded, color: ink),
              onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: kTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickModulesBar(
    BuildContext context,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/hazirbulunusluk'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: kTeal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hazırbulunuşluk',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.caption(ink, w: FontWeight.w700),
                        ),
                        Text(
                          'RPE & Yük Dengesi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/ekipman-tuning'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D7581).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: Color(0xFF555D68),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ekipman Tuning',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.caption(ink, w: FontWeight.w700),
                        ),
                        Text(
                          'Yay & Ok Balistiği',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox(Color surf, Color line, Color ink) {
    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _filter = v.trim()),
        style: SwanType.bodySm(ink),
        decoration: InputDecoration(
          hintText: 'Kadroda sporcu ara…',
          hintStyle: SwanType.bodySm(SwanColors.textSecondary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: SwanColors.textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeTabs(Color surf, Color line, Color ink) {
    final ranges = [
      ('7d', 'Son 7 Gün'),
      ('month', 'Bu Ay'),
      ('season', 'Sezonluk'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: ranges.map((r) {
          final isSelected = _timeRange == r.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _timeRange = r.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? kTeal : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: kTeal.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  r.$2,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF061424) : SwanColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeroAthleticCard(Color surf, Color line, Color ink) {
    return Container(
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
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kTeal.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: kTeal,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'KONDİSYON SEVİYESİ',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: kTeal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Swan Atletik İndeks',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2B3C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: line),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up_rounded, size: 14, color: kTeal),
                          const SizedBox(width: 4),
                          Text(
                            '+4% Bu Hafta',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SwanRing(
                      value: 0.88,
                      track: const Color(0xFF1E2B3C),
                      progress: kTeal,
                      size: 78,
                      stroke: 8,
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '88',
                            style: GoogleFonts.sora(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          Text(
                            '/ 100',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: SwanColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Pik Formda',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kTeal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Nöromüsküler tazelik ve kardiyak verim dengede. Yüksek tempolu intervallere hazır.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFFBBC9C7),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: kTeal,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Kalp: 94%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: SwanColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF8C6F),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tazelik: 82%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: SwanColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricsGrid(Color surf, Color line, Color ink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Biyometrik Metrikler',
              style: SwanType.h3(ink),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: kTeal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Canlı Sensör',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kTeal,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.32,
          children: [
            _biometricTile(
              icon: Icons.air_rounded,
              iconColor: kTeal,
              badge: 'İlk %5',
              badgeColor: const Color(0xFF293547),
              badgeTextColor: kTeal,
              label: 'VO2 MAX',
              value: '54.2',
              unit: 'ml/kg/dk',
              status: 'Mükemmel Seviye',
              statusColor: kTeal,
              surf: surf,
              line: line,
            ),
            _biometricTile(
              icon: Icons.favorite_rounded,
              iconColor: const Color(0xFFFF8C6F),
              badge: 'Sabit Trend',
              badgeColor: const Color(0xFF293547),
              badgeTextColor: const Color(0xFFC0C6D9),
              label: 'DİNLENİK NABIZ',
              value: '48',
              unit: 'BPM',
              status: 'Bradikardi (Atletik)',
              statusColor: const Color(0xFFBBC9C7),
              surf: surf,
              line: line,
            ),
            _biometricTile(
              icon: Icons.speed_rounded,
              iconColor: kTeal,
              badge: 'Optimal',
              badgeColor: kTeal.withValues(alpha: 0.18),
              badgeTextColor: kTeal,
              label: 'İŞ YÜKÜ (ACWR)',
              value: '1.15',
              unit: 'Oran',
              status: 'Düşük Sakatlık Riski',
              statusColor: const Color(0xFFBBC9C7),
              surf: surf,
              line: line,
            ),
            _biometricTile(
              icon: Icons.snooze_rounded,
              iconColor: const Color(0xFFC0C6D9),
              badge: '78 ms HRV',
              badgeColor: const Color(0xFF293547),
              badgeTextColor: const Color(0xFFC0C6D9),
              label: 'TOPARLANMA',
              value: '18',
              unit: 'Saat Kaldı',
              status: 'HRV Dengeli & Hazır',
              statusColor: kTeal,
              surf: surf,
              line: line,
            ),
          ],
        ),
      ],
    );
  }

  Widget _biometricTile({
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required String label,
    required String value,
    required String unit,
    required String status,
    required Color statusColor,
    required Color surf,
    required Color line,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2B3C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: SwanColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: SwanColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeIntensityChart(Color surf, Color line, Color ink) {
    final days = [
      ('Pzt', 0.60, 0.30),
      ('Sal', 0.85, 0.45),
      ('Çar', 0.20, 0.0),
      ('Per', 0.75, 0.35),
      ('Cum', 0.95, 0.50),
      ('Cmt', 0.40, 0.0),
      ('Paz', 0.70, 0.20),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
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
                    'Hacim & Yoğunluk',
                    style: SwanType.h3(Colors.white),
                  ),
                  Text(
                    'Haftalık antrenman stres dağılımı',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2B3C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 14, color: kTeal),
                    const SizedBox(width: 4),
                    Text(
                      '42.8 km Toplam',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: days.map((d) {
                final isSunday = d.$1 == 'Paz';
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 22,
                        height: 90 * d.$2,
                        decoration: const BoxDecoration(
                          color: Color(0xFF293547),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (d.$3 > 0)
                              Container(
                                height: (90 * d.$2) * (d.$3 / d.$2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF8C6F),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                                ),
                              ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kTeal,
                                  borderRadius: d.$3 > 0
                                      ? BorderRadius.zero
                                      : const BorderRadius.vertical(top: Radius.circular(5)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d.$1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: isSunday ? FontWeight.w800 : FontWeight.w600,
                          color: isSunday ? kTeal : SwanColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1C2D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _chartLegendItem(kTeal, 'Koşu (km)'),
                _chartLegendItem(const Color(0xFFFF8C6F), 'Kuvvet Tonajı'),
                _chartLegendItem(const Color(0xFFC0C6D9), 'RPE Şiddeti'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: SwanColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeartRateZoneCard(Color surf, Color line, Color ink) {
    final zones = [
      ('Z1: Aktif Toparlanma', '105-125 BPM', '1s 05dk', const Color(0xFFC0C6D9), false),
      ('Z2: Aerobik Taban (Yağ Yakımı)', '126-148 BPM', '3s 10dk', kTeal, true),
      ('Z3: Tempo & Ritim', '149-162 BPM', '1s 20dk', const Color(0xFF2FBFB6), false),
      ('Z4: Laktat Eşiği', '163-176 BPM', '50 dk', const Color(0xFFFF8C6F), false),
      ('Z5: Anaerobik Kapasite', '>177 BPM', '20 dk', const Color(0xFFFF5252), false),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132031),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
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
                  Text('Nabız Bölgesi Dağılımı', style: SwanType.h3(Colors.white)),
                  Text(
                    'Son 7 gün toplam: 6s 45dk',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              const Icon(
                Icons.monitor_heart_rounded,
                size: 20,
                color: SwanColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(flex: 15, child: Container(color: const Color(0xFFC0C6D9))),
                  Expanded(flex: 45, child: Container(color: kTeal)),
                  Expanded(flex: 20, child: Container(color: const Color(0xFF2FBFB6))),
                  Expanded(flex: 15, child: Container(color: const Color(0xFFFF8C6F))),
                  Expanded(flex: 5, child: Container(color: const Color(0xFFFF5252))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: zones.map((z) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: z.$5 ? const Color(0xFF1E2B3C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: z.$4,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          z.$1,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: z.$5 ? FontWeight.w700 : FontWeight.w600,
                            color: z.$5 ? kTeal : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          z.$2,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: z.$5 ? kTeal : SwanColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 48,
                          child: Text(
                            z.$3,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: z.$5 ? kTeal : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwanAiCoachCard(Color surf, Color line, Color ink) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2B3C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kTeal.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              size: 22,
              color: kTeal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SwanAI Koç Notu',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: kTeal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bugün 09:30',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kTeal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFFBBC9C7),
                      height: 1.4,
                    ),
                    children: const [
                      TextSpan(text: 'Bu hafta aerobik dayanıklılık hacmin '),
                      TextSpan(
                        text: '%12 arttı',
                        style: TextStyle(color: kTeal, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '. Hafta sonu hedeflenen maç/koşu öncesinde kas glikojen depolarını tazelemek için ',
                      ),
                      TextSpan(
                        text: '1 gün aktif toparlanma (Zone 1)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' önerilir.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Antrenman planı optimize edildi.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        foregroundColor: const Color(0xFF061424),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Antrenmanı Optimize Et',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: line),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Detaylı Rapor',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBleSensorBar(Color surf, Color line, Color ink) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF132031),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  size: 16,
                  color: kTeal,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BLE Kayış Bağlı',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Polar H10 • Pil 92%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: SwanColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sensör verileri güncellendi.')),
              );
            },
            icon: const Icon(Icons.sync_rounded, size: 14),
            label: Text(
              'Şimdi Eşitle',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E2B3C),
              foregroundColor: kTeal,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: kTeal.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(
    bool isDark,
    Color ink,
    int total,
    int withTests,
    List<({String athleteId, String name, int tests, int goals, int progress, DateTime? lastTest})>
        rows,
  ) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final openGoals = rows.fold<int>(0, (n, r) => n + r.goals);
    final coverage = total == 0 ? 0.0 : withTests / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ölçüm kapsamı',
                  style: SwanType.caption(SwanColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Text('$withTests / $total', style: SwanType.display(ink)),
                const SizedBox(height: 3),
                Text(
                  '$openGoals açık gelişim hedefi',
                  style: SwanType.caption(SwanColors.textSecondary),
                ),
              ],
            ),
          ),
          SwanRing(
            value: coverage,
            track: line,
            progress: kTeal,
            size: 56,
            stroke: 6,
            center: Text(
              '%${(coverage * 100).round()}',
              style: SwanType.caption(ink, w: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    bool isDark,
    Color ink,
    ({String athleteId, String name, int tests, int goals, int progress, DateTime? lastTest})
        r,
  ) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final never = r.tests == 0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/sporcu-performans',
        arguments: {'id': r.athleteId, 'name': r.name},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(
          children: [
            GradientAvatar(
              initials: r.name.isEmpty ? '?' : r.name[0].toUpperCase(),
              size: 40,
              gradientIndex: r.athleteId.hashCode.abs() % 4,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name.isEmpty ? 'Sporcu' : r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(ink, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    never
                        ? 'Henüz ölçüm yok'
                        : '${r.tests} test · ${r.goals} açık hedef'
                            '${r.lastTest == null ? '' : ' · son ${r.lastTest!.day}.${r.lastTest!.month}'}',
                    style: SwanType.caption(
                      never
                          ? SwanPalette.light.warning
                          : SwanColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (r.goals > 0)
              SizedBox(
                width: 46,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: r.progress / 100,
                        minHeight: 5,
                        backgroundColor: line,
                        valueColor: const AlwaysStoppedAnimation(kTeal),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '%${r.progress}',
                      style: SwanType.caption(kTeal, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: SwanColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
