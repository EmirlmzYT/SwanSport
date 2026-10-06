import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'test_categories.dart';

/// Bir sporcunun performans dosyası — test seyri, atış dispersiyon analizi ve gelişim hedefleri.
///
/// Calm Athletic Modernism (Stitch `performans_ve_at_analizi`) tasarımıyla
/// 70 metre hedef dispersiyon grafiği, seri skor ortalaması ve biyomekanik metrikler sunar.
class AthletePerformanceScreen extends ConsumerStatefulWidget {
  const AthletePerformanceScreen({
    super.key,
    required this.athleteId,
    required this.athleteName,
  });

  final String athleteId;
  final String athleteName;

  @override
  ConsumerState<AthletePerformanceScreen> createState() =>
      _AthletePerformanceScreenState();
}

class _AthletePerformanceScreenState
    extends ConsumerState<AthletePerformanceScreen> {
  int _activeSegment = 0; // 0: Atış & İsabet Grubu, 1: Testler & Hedefler
  int _timeHorizonIndex = 0; // 0: Son 30 Gün, 1: Bu Sezon, 2: Müsabaka Karşılaştırmalı

  final List<String> _timeHorizons = const [
    'Son 30 Gün',
    'Bu Sezon',
    'Müsabaka Karşılaştırmalı',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final canManage =
        ref.watch(canManageAthleteProvider(widget.athleteId)).valueOrNull ??
            false;
    final series = ref.watch(testSeriesProvider(widget.athleteId));
    final goals = ref.watch(goalsProvider(widget.athleteId));

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
                ref.invalidate(testSeriesProvider(widget.athleteId));
                ref.invalidate(goalsProvider(widget.athleteId));
                await ref.read(testSeriesProvider(widget.athleteId).future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
                children: [
                  _buildTopBar(context, ink, surf, line),
                  const SizedBox(height: 14),
                  _buildAthleteProfileCard(isDark, surf, line, ink),
                  const SizedBox(height: 14),
                  _buildTimeHorizonSelector(isDark),
                  const SizedBox(height: 16),
                  _buildSegmentSwitcher(isDark, surf, line, ink),
                  const SizedBox(height: 18),
                  if (_activeSegment == 0) ...[
                    _buildMetricsBentoGrid(isDark, surf, line, ink),
                    const SizedBox(height: 16),
                    _buildArcheryTargetCard(isDark, surf, line, ink),
                    const SizedBox(height: 16),
                    _buildScoreProgressionCard(isDark, surf, line, ink),
                    const SizedBox(height: 16),
                    _buildCoachAssessmentCard(isDark, surf, line, ink),
                    const SizedBox(height: 20),
                    _buildShareReportButton(context),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Test Sonuçları',
                            style: SwanType.h3(ink),
                          ),
                        ),
                        if (canManage)
                          GestureDetector(
                            onTap: () => _addTest(context, ref),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: kTeal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Test Ekle',
                                  style: SwanType.caption(
                                    kTeal,
                                    w: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    series.when(
                      loading: premiumLoading,
                      error: (e, _) => premiumError(context, '$e'),
                      data: (list) {
                        if (list.isEmpty) {
                          return _empty(
                            isDark,
                            Icons.analytics_outlined,
                            canManage
                                ? 'Henüz test yok. “Test Ekle” ile başla.'
                                : 'Henüz test kaydı yok.',
                          );
                        }
                        return Column(
                          children: list
                              .map(
                                (s) => _seriesCard(
                                  context,
                                  ref,
                                  isDark,
                                  s,
                                  canManage,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Gelişim Hedefleri',
                            style: SwanType.h3(ink),
                          ),
                        ),
                        if (canManage)
                          GestureDetector(
                            onTap: () => _addGoal(context, ref),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: kTeal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Hedef Ekle',
                                  style: SwanType.caption(
                                    kTeal,
                                    w: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    goals.when(
                      loading: premiumLoading,
                      error: (e, _) => premiumError(context, '$e'),
                      data: (list) {
                        if (list.isEmpty) {
                          return _empty(
                            isDark,
                            Icons.flag_outlined,
                            'Henüz gelişim hedefi yok.',
                          );
                        }
                        return Column(
                          children: list
                              .map(
                                (g) => _goalCard(
                                  context,
                                  ref,
                                  isDark,
                                  g,
                                  canManage,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    Color ink,
    Color surf,
    Color line,
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
                  'SwanSport',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
                Text('Performans', style: SwanType.h2(ink)),
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
              child: Center(
                child: Text(
                  widget.athleteName.isNotEmpty
                      ? widget.athleteName[0].toUpperCase()
                      : 'S',
                  style: SwanType.caption(Colors.white, w: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAthleteProfileCard(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GradientAvatar(
                initials: widget.athleteName.isNotEmpty
                    ? widget.athleteName[0].toUpperCase()
                    : '?',
                size: 58,
                gradientIndex: widget.athleteId.hashCode.abs() % 4,
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: kTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.athleteName.isEmpty
                            ? 'Sporcu'
                            : widget.athleteName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.h2(ink),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#${widget.athleteId.length > 8 ? widget.athleteId.substring(0, 8).toUpperCase() : "2025-089"}',
                        style: SwanType.caption(kTeal, w: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'U18 Klasik Yay',
                  style: SwanType.bodySm(SwanColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: kTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Milli Takım Barajı: Aday',
                      style: SwanType.caption(kTeal, w: FontWeight.w700),
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

  Widget _buildTimeHorizonSelector(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_timeHorizons.length, (i) {
          final isSelected = _timeHorizonIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _timeHorizonIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kTeal
                      : (isDark ? SwanPalette.dark : SwanPalette.light).surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? kTeal
                        : (isDark ? SwanPalette.dark : SwanPalette.light).line,
                  ),
                ),
                child: Text(
                  _timeHorizons[i],
                  style: SwanType.caption(
                    isSelected ? Colors.white : SwanColors.textSecondary,
                    w: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSegmentSwitcher(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegment = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeSegment == 0 ? surf : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeSegment == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Atış & İsabet Grubu',
                  style: SwanType.bodySm(
                    _activeSegment == 0 ? kTeal : SwanColors.textSecondary,
                    w: _activeSegment == 0 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegment = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _activeSegment == 1 ? surf : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _activeSegment == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Testler & Hedefler',
                  style: SwanType.bodySm(
                    _activeSegment == 1 ? kTeal : SwanColors.textSecondary,
                    w: _activeSegment == 1 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBentoGrid(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ortalama Seri Skoru',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('57.4', style: SwanType.display(ink)),
                      const SizedBox(width: 4),
                      Text(
                        '/ 60',
                        style: SwanType.body(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 16,
                        color: kTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+1.8 artış (Bu ay)',
                        style: SwanType.caption(kTeal, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
              SwanRing(
                value: 0.956,
                track: line,
                progress: kTeal,
                size: 58,
                stroke: 6,
                center: Text(
                  '%95.6',
                  style: SwanType.caption(ink, w: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: line),
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
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: kTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: kTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tetikleme & Bırakış Tutarlılığı',
                        style: SwanType.bodySm(ink, w: FontWeight.w600),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? SwanPalette.dark.surfaceAlt
                          : const Color(0xFFF1F4F7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Gelişmiş Metrik',
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('%94', style: SwanType.h1(ink)),
                      Text(
                        'Senkronizasyon Doğruluğu',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _miniBar(12, const Color(0xFFC0C6DB)),
                      const SizedBox(width: 4),
                      _miniBar(20, const Color(0xFFC0C6DB)),
                      const SizedBox(width: 4),
                      _miniBar(24, kTeal.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      _miniBar(28, kTeal),
                      const SizedBox(width: 4),
                      _miniBar(32, kTeal),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniBar(double height, Color color) {
    return Container(
      width: 6,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildArcheryTargetCard(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
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
                  Text('İsabet Grubu Dağılımı', style: SwanType.h3(ink)),
                  const SizedBox(height: 2),
                  Text(
                    '70 Metre Hedef Dispersiyon Analizi',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? SwanPalette.dark.surfaceAlt
                      : const Color(0xFFF1F4F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: kTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '120 Ok',
                      style: SwanType.caption(ink, w: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CustomPaint(
                    painter: _ArcheryTargetPainter(),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: surf.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Saat 1 Yönü',
                          style: SwanType.caption(
                            kTeal,
                            w: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Sıkı Gruplama',
                          style: SwanType.caption(
                            SwanColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildRingBreakdown(
            'Sarı (X - 10 - 9)',
            '%82',
            0.82,
            const Color(0xFFFACC15),
            kTeal,
          ),
          const SizedBox(height: 8),
          _buildRingBreakdown(
            'Kırmızı (8 - 7)',
            '%15',
            0.15,
            const Color(0xFFC05555),
            const Color(0xFF575E70),
          ),
          const SizedBox(height: 8),
          _buildRingBreakdown(
            'Mavi (6 - 5)',
            '%3',
            0.03,
            const Color(0xFF575E70),
            const Color(0xFFBDC9CA),
          ),
        ],
      ),
    );
  }

  Widget _buildRingBreakdown(
    String label,
    String pctText,
    double pct,
    Color dotColor,
    Color barColor,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: SwanType.caption(SwanColors.textPrimary),
                ),
              ],
            ),
            Text(
              pctText,
              style: SwanType.caption(
                SwanColors.textPrimary,
                w: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: const Color(0xFFE5E8EB),
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreProgressionCard(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    final scores = [
      (label: '#1', score: 332, pct: 0.62, peak: false),
      (label: '#2', score: 338, pct: 0.68, peak: false),
      (label: '#3', score: 341, pct: 0.72, peak: false),
      (label: '#4', score: 340, pct: 0.70, peak: false),
      (label: '#5', score: 346, pct: 0.80, peak: false),
      (label: 'Son', score: 348, pct: 0.85, peak: true),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
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
                  Text('İdman Skor İlerlemesi', style: SwanType.h3(ink)),
                  const SizedBox(height: 2),
                  Text(
                    'Son 6 Seans (Maks. 360 Puan)',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.north_east_rounded, size: 16, color: kTeal),
                  const SizedBox(width: 2),
                  Text(
                    '+16 Puan',
                    style: SwanType.caption(kTeal, w: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: scores.map((s) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (s.peak)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: kTeal,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${s.score}',
                              style: SwanType.caption(
                                Colors.white,
                                w: FontWeight.w800,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${s.score}',
                              style: SwanType.caption(
                                SwanColors.textSecondary,
                                w: FontWeight.w600,
                              ),
                            ),
                          ),
                        Container(
                          height: 80 * s.pct,
                          decoration: BoxDecoration(
                            color: s.peak
                                ? kTeal
                                : (isDark
                                    ? SwanPalette.dark.surfaceAlt
                                    : const Color(0xFFE5E8EB)),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.label,
                          style: SwanType.caption(
                            s.peak ? kTeal : SwanColors.textSecondary,
                            w: s.peak ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachAssessmentCard(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kTeal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: kTeal,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'AK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ahmet Kaya',
                        style: SwanType.bodySm(ink, w: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(Başantrenör)',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    'Dün, 18:40 Değerlendirmesi',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '“70 metre rüzgar toleransı son 2 haftada belirgin arttı. Clicker düşüş süresi 3.2 sn stabil seviyede, atış ritmi şampiyona standartlarında.”',
            style: SwanType.bodySm(ink),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: kTeal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Rüzgar Toleransı: Yüksek',
                      style: SwanType.caption(kTeal, w: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: kTeal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '3.2 sn Clicker',
                      style: SwanType.caption(kTeal, w: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareReportButton(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Zeynep Yılmaz Performans Raporu PDF olarak hazırlandı.',
                  ),
                  backgroundColor: kTeal,
                ),
              );
            },
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            label: const Text('Gelişim Raporunu Paylaş (PDF / Veli)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              textStyle: SwanType.body(Colors.white, w: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rapor dijital imzalı olup sporcu lisans kütüğüne otomatik işlenir.',
          textAlign: TextAlign.center,
          style: SwanType.caption(SwanColors.textSecondary),
        ),
      ],
    );
  }

  Widget _empty(bool isDark, IconData icon, String text) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: SwanColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: SwanType.caption(SwanColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- test kartı
  Widget _seriesCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    TestSeries s,
    bool canManage,
  ) {
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final color = categoryColor(s.category, isDark);

    final change = s.changePercent;
    final improved = s.improved;

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.lg),
      padding: const EdgeInsets.only(bottom: SwanSpace.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(categoryIcon(s.category), size: 19, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.body(ink, w: FontWeight.w700),
                    ),
                    Text(
                      categoryLabel(s.category),
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(s.latest.valueLabel, style: SwanType.h2(ink)),
                  if (change != null && improved != null)
                    Row(
                      children: [
                        Icon(
                          improved
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 13,
                          color: improved
                              ? SwanPalette.light.success
                              : SwanPalette.light.danger,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${change.abs().toStringAsFixed(1)}%',
                          style: SwanType.caption(
                            improved
                                ? SwanPalette.light.success
                                : SwanPalette.light.danger,
                            w: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          if (s.records.length > 1) ...[
            const SizedBox(height: 14),
            _sparkBars(s, color, line),
            const SizedBox(height: 6),
            Text(
              '${s.records.length} ölçüm · ilk '
              '${_d(s.records.first.testDate)} → son '
              '${_d(s.latest.testDate)}',
              style: SwanType.caption(SwanColors.textSecondary),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Tek ölçüm · ${_d(s.latest.testDate)}',
              style: SwanType.caption(SwanColors.textSecondary),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                await ref
                    .read(performanceServiceProvider)
                    .removeTest(s.latest.id);
                ref.invalidate(testSeriesProvider(widget.athleteId));
              },
              child: Text(
                'Son ölçümü sil',
                style: SwanType.caption(
                  SwanColors.textSecondary,
                  w: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sparkBars(TestSeries s, Color color, Color track) {
    final values = s.records.map((r) => r.value.toDouble()).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final span = (maxV - minV).abs() < 0.0001 ? 1.0 : maxV - minV;

    return SizedBox(
      height: 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final norm = (values[i] - minV) / span;
          final shown = s.lowerIsBetter ? 1 - norm : norm;
          final isLast = i == values.length - 1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 8 + shown * 34,
                  decoration: BoxDecoration(
                    color: isLast ? color : color.withValues(alpha: .35),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ------------------------------------------------------- hedef kartı
  Widget _goalCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    DevelopmentGoal g,
    bool canManage,
  ) {
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final (statusColor, statusIcon) = switch (g.status) {
      'done' => (SwanPalette.light.success, Icons.check_circle_rounded),
      'at_risk' => (SwanPalette.light.danger, Icons.warning_rounded),
      _ => (SwanPalette.light.warning, Icons.schedule_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.lg),
      padding: const EdgeInsets.only(bottom: SwanSpace.lg),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.title,
                  style: SwanType.bodySm(ink, w: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              PremiumStatusChip(
                label: g.statusLabel,
                color: statusColor,
                icon: statusIcon,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              categoryLabel(g.category),
              if (g.targetDate != null) 'Hedef: ${_d(g.targetDate!)}',
            ].join(' · '),
            style: SwanType.caption(SwanColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: g.progress / 100,
                    minHeight: 8,
                    backgroundColor: line,
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('%${g.progress}', style: SwanType.h3(ink)),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _step(context, ref, g, -10, '−10'),
                const SizedBox(width: 8),
                _step(context, ref, g, 10, '+10'),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await ref.read(performanceServiceProvider).removeGoal(g.id);
                    ref.invalidate(goalsProvider(widget.athleteId));
                  },
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: SwanColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context,
    WidgetRef ref,
    DevelopmentGoal g,
    int delta,
    String label,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    return GestureDetector(
      onTap: () async {
        await ref
            .read(performanceServiceProvider)
            .setGoalProgress(g.id, g.progress + delta);
        ref.invalidate(goalsProvider(widget.athleteId));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: alt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: SwanType.caption(ink, w: FontWeight.w800)),
      ),
    );
  }

  String _d(DateTime d) {
    const m = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${d.day} ${m[d.month - 1]}';
  }

  // -------------------------------------------------------------- formlar
  Future<void> _addTest(BuildContext context, WidgetRef ref) async {
    final name = FormField_('Test adı', hint: '30 m sprint');
    final value = FormField_(
      'Sonuç',
      hint: '4.2',
      keyboard: const TextInputType.numberWithOptions(decimal: true),
    );
    final unit = FormField_('Birim', hint: 'sn / kg / m', required: false);
    final cat = FormField_(
      'Kategori',
      hint: 'surat / dayaniklilik / kuvvet / teknik',
      required: false,
    );
    final lower = FormField_(
      'Küçük değer iyi mi? (e/h)',
      hint: 'e',
      required: false,
    );

    final ok = await showQuickForm(
      context,
      title: 'Test Sonucu Ekle',
      note: 'Süre gibi testlerde “küçük değer iyi” için e yaz.',
      fields: [name, value, unit, cat, lower],
      onSubmit: () async {
        final v = num.tryParse(value.value.replaceAll(',', '.'));
        if (v == null) throw 'Sonuç sayı olmalı';
        final key = kTestCategories
                .where((c) => c.key == cat.value.toLowerCase().trim())
                .isNotEmpty
            ? cat.value.toLowerCase().trim()
            : 'surat';
        await ref.read(performanceServiceProvider).addTest(
              athleteId: widget.athleteId,
              category: key,
              testName: name.value,
              value: v,
              unit: unit.value,
              lowerIsBetter: lower.value.toLowerCase().startsWith('e'),
            );
      },
    );
    if (ok == true) ref.invalidate(testSeriesProvider(widget.athleteId));
  }

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final title = FormField_('Hedef', hint: 'Sprint süresini 4.0 sn’ye indir');
    final cat = FormField_(
      'Kategori',
      hint: 'surat / dayaniklilik / kuvvet / teknik',
      required: false,
    );
    final date = FormField_('Hedef tarih', hint: '2026-12-31', required: false);

    final ok = await showQuickForm(
      context,
      title: 'Gelişim Hedefi Ekle',
      fields: [title, cat, date],
      onSubmit: () {
        final key = kTestCategories
                .where((c) => c.key == cat.value.toLowerCase().trim())
                .isNotEmpty
            ? cat.value.toLowerCase().trim()
            : 'surat';
        return ref.read(performanceServiceProvider).addGoal(
              athleteId: widget.athleteId,
              title: title.value,
              category: key,
              targetDate: DateTime.tryParse(date.value),
            );
      },
    );
    if (ok == true) ref.invalidate(goalsProvider(widget.athleteId));
  }
}

/// World Archery standartlarında 10 halkalı hedef ve 1 o'clock dispersiyon kümelenmesi çizen CustomPainter
class _ArcheryTargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Rings from outer (1-2) to inner (10-X)
    final rings = [
      (radius: maxRadius * 0.98, color: const Color(0xFFF8FAFC)), // White 1-2
      (radius: maxRadius * 0.80, color: const Color(0xFFEBEEF1)),
      (radius: maxRadius * 0.65, color: const Color(0xFF3D494A)), // Black 3-4
      (radius: maxRadius * 0.50, color: const Color(0xFF575E70)), // Blue 5-6
      (radius: maxRadius * 0.36, color: const Color(0xFFC05555)), // Red 7-8
      (radius: maxRadius * 0.22, color: const Color(0xFFEAB308)), // Yellow 9-10
      (radius: maxRadius * 0.10, color: const Color(0xFFFACC15)), // Gold X
    ];

    for (final r in rings) {
      final paint = Paint()
        ..color = r.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, r.radius, paint);
    }

    // Crosshairs
    final linePaint = Paint()
      ..color = const Color(0xFF181C1E).withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx, 10),
      Offset(center.dx, size.height - 10),
      linePaint,
    );
    canvas.drawLine(
      Offset(10, center.dy),
      Offset(size.width - 10, center.dy),
      linePaint,
    );

    // Heat dispersion cluster offset: 1 o'clock (~ +12px x, -12px y)
    final clusterCenter = Offset(center.dx + 12, center.dy - 12);

    // Glow aura
    final glowPaint1 = Paint()
      ..color = kTeal.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(clusterCenter, 24, glowPaint1);

    final glowPaint2 = Paint()
      ..color = const Color(0xFF00818A).withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(clusterCenter, 14, glowPaint2);

    // Arrow strikes (tight cluster at 1 o'clock)
    final arrowPaint = Paint()
      ..color = const Color(0xFF004F54)
      ..style = PaintingStyle.fill;

    final strikes = [
      Offset(clusterCenter.dx + 2, clusterCenter.dy - 1),
      Offset(clusterCenter.dx - 3, clusterCenter.dy + 3),
      Offset(clusterCenter.dx + 3, clusterCenter.dy + 3),
      Offset(clusterCenter.dx - 1, clusterCenter.dy - 4),
      Offset(clusterCenter.dx - 5, clusterCenter.dy - 1),
      Offset(clusterCenter.dx + 5, clusterCenter.dy - 2),
      Offset(clusterCenter.dx + 7, clusterCenter.dy + 5),
      Offset(clusterCenter.dx - 6, clusterCenter.dy + 4),
    ];

    for (final s in strikes) {
      canvas.drawCircle(s, 3.5, arrowPaint);
    }

    // Outlier strikes in outer rings
    final outlierPaint = Paint()
      ..color = const Color(0xFF181C1E).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx + 26, center.dy - 22),
      3.0,
      outlierPaint,
    ); // 8-ring
    canvas.drawCircle(
      Offset(center.dx - 18, center.dy + 20),
      3.0,
      outlierPaint,
    ); // 7-ring
    canvas.drawCircle(
      Offset(center.dx + 38, center.dy + 28),
      3.0,
      outlierPaint,
    ); // 6-ring
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
