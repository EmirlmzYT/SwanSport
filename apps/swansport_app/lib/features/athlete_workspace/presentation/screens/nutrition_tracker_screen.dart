import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// SwanSport - Beslenme & Makro Takip Günlüğü (Stitch Screen 16)
///
/// Metabolik yakıt dengesi, kalori hedef göstergesi, makro ayrışımı (Protein, Karb, Yağ),
/// etkileşimli hidrasyon takibi, SwanAI akıllı beslenme önerisi ve öğün günlüğü.
class NutritionTrackerScreen extends ConsumerStatefulWidget {
  const NutritionTrackerScreen({super.key});

  @override
  ConsumerState<NutritionTrackerScreen> createState() =>
      _NutritionTrackerScreenState();
}

class _NutritionTrackerScreenState extends ConsumerState<NutritionTrackerScreen> {
  DateTime _currentDate = DateTime.now();
  double _waterLiters = 2.8;
  final double _targetWater = 3.5;

  final List<Map<String, dynamic>> _meals = [
    {
      'title': 'Kahvaltı',
      'desc': 'Yulaf, Yumurta Beyazı, Muz, Fıstık Ezmesi',
      'kcal': 680,
      'protein': '42g',
      'carb': '85g',
      'fat': '18g',
      'completed': true,
      'icon': Icons.breakfast_dining_rounded,
    },
    {
      'title': 'Antrenman Öncesi Yakıt',
      'desc': 'Maltodekstrin & BCAA Shaker',
      'kcal': 210,
      'protein': '8g',
      'carb': '44g',
      'fat': '0g',
      'completed': true,
      'icon': Icons.bolt_rounded,
    },
    {
      'title': 'Öğle Yemeği',
      'desc': 'Izgara Tavuk Göğsü, Kinoa, Avokado',
      'kcal': 840,
      'protein': '78g',
      'carb': '92g',
      'fat': '26g',
      'completed': true,
      'icon': Icons.lunch_dining_rounded,
    },
    {
      'title': 'Akşam Yemeği',
      'desc': 'Hedef: ~920 kcal planlanıyor',
      'kcal': 0,
      'protein': '0g',
      'carb': '0g',
      'fat': '0g',
      'completed': false,
      'icon': Icons.dinner_dining_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;

    final completedMealsCount = _meals.where((m) => m['completed'] == true).length;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _buildHeader(context, palette),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      // Date Switcher Bar
                      _buildDateBar(palette),
                      const SizedBox(height: 14),

                      // Hero Caloric Fueling Gauge Card
                      _buildCaloricFuelingCard(palette, isDark),
                      const SizedBox(height: 16),

                      // Macro Split Progress Metrics
                      _buildMacroSplitGrid(palette, isDark),
                      const SizedBox(height: 16),

                      // Interactive Hydration Tracker
                      _buildHydrationTracker(palette, isDark),
                      const SizedBox(height: 16),

                      // SwanAI Recommendation Banner
                      _buildAiRecommendationBanner(palette, isDark),
                      const SizedBox(height: 18),

                      // Meal Log Header & List
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Öğün Günlüğü',
                            style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                          ),
                          Text(
                            '$completedMealsCount/${_meals.length} Tamamlandı',
                            style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      for (int i = 0; i < _meals.length; i++)
                        _buildMealCard(_meals[i], i, palette, isDark),
                    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Column(
            children: [
              Text(
                'Beslenme & Makro Günlüğü',
                style: SwanType.h3(palette.ink),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'SwanFit Beslenme',
                    style: SwanType.caption(palette.accent, w: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 18,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBar(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _currentDate = _currentDate.subtract(const Duration(days: 1));
              });
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: palette.ink,
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: palette.accent),
              const SizedBox(width: 8),
              Builder(
                builder: (_) {
                  const months = [
                    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
                    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
                  ];
                  final isToday = _currentDate.year == DateTime.now().year &&
                      _currentDate.month == DateTime.now().month &&
                      _currentDate.day == DateTime.now().day;
                  return Column(
                    children: [
                      Text(
                        isToday ? 'Bugün' : '${_currentDate.day} ${months[_currentDate.month - 1]}',
                        style: SwanType.bodySm(palette.ink, w: FontWeight.w800),
                      ),
                      Text(
                        '${_currentDate.day} ${months[_currentDate.month - 1]} ${_currentDate.year}',
                        style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 11),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _currentDate = _currentDate.add(const Duration(days: 1));
              });
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloricFuelingCard(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface,
            palette.surfaceAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                    'METABOLİK YAKIT DENGESİ',
                    style: SwanType.caption(palette.accent, w: FontWeight.w800).copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '2.850',
                        style: SwanType.h2(palette.ink),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'kcal hedef',
                        style: SwanType.caption(palette.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepOrangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.deepOrangeAccent),
                    const SizedBox(width: 4),
                    Text(
                      '+640 kcal yakıldı',
                      style: SwanType.caption(Colors.deepOrangeAccent, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Radial Arc Display
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 0.68,
                        strokeWidth: 8,
                        backgroundColor: palette.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '920',
                          style: SwanType.body(palette.accent, w: FontWeight.w900),
                        ),
                        Text(
                          'kcal kaldı',
                          style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Metric breakdown list
              Expanded(
                child: Column(
                  children: [
                    _buildFuelRow(
                      label: 'Alınan',
                      value: '1.930 kcal',
                      dotColor: palette.accent,
                      palette: palette,
                    ),
                    const SizedBox(height: 6),
                    _buildFuelRow(
                      label: 'Antrenman',
                      value: '+640 kcal',
                      dotColor: Colors.deepOrangeAccent,
                      palette: palette,
                    ),
                    const SizedBox(height: 6),
                    _buildFuelRow(
                      label: 'Net İhtiyaç',
                      value: '1.560 kcal',
                      dotColor: Colors.blueAccent,
                      palette: palette,
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

  Widget _buildFuelRow({
    required String label,
    required String value,
    required Color dotColor,
    required SwanPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
              ),
            ],
          ),
          Text(
            value,
            style: SwanType.caption(palette.ink, w: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroSplitGrid(SwanPalette palette, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Makro Besinler',
              style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            ),
            Text(
              'Hedef %86',
              style: SwanType.caption(palette.accent, w: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Protein
            Expanded(
              child: _buildMacroCard(
                title: 'Protein',
                percent: '%92',
                current: '165',
                target: '180g',
                progress: 0.92,
                color: palette.accent,
                palette: palette,
              ),
            ),
            const SizedBox(width: 8),
            // Karb
            Expanded(
              child: _buildMacroCard(
                title: 'Karb',
                percent: '%85',
                current: '290',
                target: '340g',
                progress: 0.85,
                color: Colors.amber.shade700,
                palette: palette,
              ),
            ),
            const SizedBox(width: 8),
            // Yağ
            Expanded(
              child: _buildMacroCard(
                title: 'Yağ',
                percent: '%82',
                current: '62',
                target: '75g',
                progress: 0.82,
                color: Colors.purpleAccent,
                palette: palette,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroCard({
    required String title,
    required String percent,
    required String current,
    required String target,
    required double progress,
    required Color color,
    required SwanPalette palette,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
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
              Text(
                title,
                style: SwanType.caption(color, w: FontWeight.w800).copyWith(fontSize: 10),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  percent,
                  style: SwanType.caption(color, w: FontWeight.w800).copyWith(fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                current,
                style: SwanType.body(palette.ink, w: FontWeight.w800),
              ),
              const SizedBox(width: 2),
              Text(
                '/ $target',
                style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 4,
              color: palette.surfaceAlt,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationTracker(SwanPalette palette, bool isDark) {
    final progress = (_waterLiters / _targetWater).clamp(0.0, 1.0);
    final percentage = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              size: 22,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _waterLiters.toStringAsFixed(1),
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w900),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '/ $_targetWater Litre',
                      style: SwanType.caption(palette.inkMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Günlük Hidrasyon %$percentage',
                  style: SwanType.caption(Colors.blueAccent, w: FontWeight.w700).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                if (_waterLiters < 5.0) {
                  _waterLiters = double.parse((_waterLiters + 0.25).toStringAsFixed(2));
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text('+250ml su eklendi! Toplam: ${_waterLiters.toStringAsFixed(1)}L'),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '+250ml',
                    style: SwanType.caption(Colors.white, w: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiRecommendationBanner(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.psychology_rounded, size: 20, color: palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SWANAI AKILLI ÖNERİ',
                      style: SwanType.caption(palette.accent, w: FontWeight.w800).copyWith(fontSize: 10),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Yarın sabahki yüksek tempolu 14K koşusu öncesi akşam öğününe 60g kompleks karbonhidrat eklemeniz glikojen depolarını optimize edecektir.',
                  style: SwanType.caption(palette.ink).copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(
    Map<String, dynamic> meal,
    int index,
    SwanPalette palette,
    bool isDark,
  ) {
    final isCompleted = meal['completed'] == true;

    if (!isCompleted) {
      // Empty action state
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line, strokeAlign: BorderSide.strokeAlignCenter),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meal['icon'] as IconData, size: 20, color: palette.inkMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal['title'] as String,
                    style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                  ),
                  Text(
                    meal['desc'] as String,
                    style: SwanType.caption(Colors.deepOrangeAccent, w: FontWeight.w600),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                _showAddFoodDialog(index, palette);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Besin Ekle',
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meal['icon'] as IconData, size: 20, color: palette.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          meal['title'] as String,
                          style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle_rounded, size: 14, color: palette.accent),
                      ],
                    ),
                    Text(
                      meal['desc'] as String,
                      style: SwanType.caption(palette.inkMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${meal['kcal']}',
                    style: SwanType.bodySm(palette.accent, w: FontWeight.w800),
                  ),
                  Text(
                    'kcal',
                    style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMacroPill('P: ${meal['protein']}', palette),
              const SizedBox(width: 6),
              _buildMacroPill('K: ${meal['carb']}', palette),
              const SizedBox(width: 6),
              _buildMacroPill('Y: ${meal['fat']}', palette),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPill(String label, SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: SwanType.caption(palette.inkMuted, w: FontWeight.w600).copyWith(fontSize: 10),
      ),
    );
  }

  void _showAddFoodDialog(int index, SwanPalette palette) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Akşam Yemeği Ekle', style: SwanType.h3(palette.ink)),
            const SizedBox(height: 8),
            Text(
              'Besin arayın veya sık kullanılan menülerden seçin:',
              style: SwanType.caption(palette.inkMuted),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Icon(Icons.restaurant_rounded, color: palette.accent),
              title: Text('Somon & Fırın Patates', style: SwanType.bodySm(palette.ink, w: FontWeight.w700)),
              subtitle: Text('720 kcal · P: 48g, K: 52g, Y: 22g', style: SwanType.caption(palette.inkMuted)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _meals[index] = {
                    'title': 'Akşam Yemeği',
                    'desc': 'Fırın Somon, Tatlı Patates, Kuşkonmaz',
                    'kcal': 720,
                    'protein': '48g',
                    'carb': '52g',
                    'fat': '22g',
                    'completed': true,
                    'icon': Icons.dinner_dining_rounded,
                  };
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.rice_bowl_rounded, color: palette.accent),
              title: Text('Hindi Fümeli Basmati Pirinç Kasesi', style: SwanType.bodySm(palette.ink, w: FontWeight.w700)),
              subtitle: Text('650 kcal · P: 54g, K: 70g, Y: 12g', style: SwanType.caption(palette.inkMuted)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _meals[index] = {
                    'title': 'Akşam Yemeği',
                    'desc': 'Hindi Füme, Basmati Pirinç, Avokado',
                    'kcal': 650,
                    'protein': '54g',
                    'carb': '70g',
                    'fat': '12g',
                    'completed': true,
                    'icon': Icons.dinner_dining_rounded,
                  };
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
