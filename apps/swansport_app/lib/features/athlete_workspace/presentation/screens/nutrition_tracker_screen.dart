import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/widgets/swan_page_header.dart';

/// Sporcunun günlük beslenme, kalori ve hidrasyon takibi.
///
/// Veriler doğrudan Supabase `athlete_nutrition_logs` tablosuna yazılır ve okunur.
class NutritionTrackerScreen extends ConsumerStatefulWidget {
  const NutritionTrackerScreen({super.key});

  @override
  ConsumerState<NutritionTrackerScreen> createState() =>
      _NutritionTrackerScreenState();
}

class _NutritionTrackerScreenState
    extends ConsumerState<NutritionTrackerScreen> {
  DateTime _selectedDate = DateTime.now();

  static const List<Map<String, dynamic>> _quickSuggestions = [
    {
      'title': 'Yulaf Lapası, Muz & Fıstık Ezmesi',
      'type': 'breakfast',
      'kcal': 420,
      'p': 16.0,
      'c': 62.0,
      'f': 12.0,
    },
    {
      'title': 'Haşlanmış Yumurta (3 adet) & Ekmek',
      'type': 'breakfast',
      'kcal': 340,
      'p': 24.0,
      'c': 26.0,
      'f': 15.0,
    },
    {
      'title': 'Izgara Tavuk Göğsü, Pirinç & Brokoli',
      'type': 'lunch',
      'kcal': 580,
      'p': 52.0,
      'c': 65.0,
      'f': 8.0,
    },
    {
      'title': 'Fırın Somon, Tatlı Patates & Salata',
      'type': 'dinner',
      'kcal': 640,
      'p': 46.0,
      'c': 48.0,
      'f': 22.0,
    },
    {
      'title': 'Lor Peynirli Sandviç',
      'type': 'snack',
      'kcal': 290,
      'p': 28.0,
      'c': 32.0,
      'f': 5.0,
    },
    {
      'title': 'Whey Protein Shake & Muz',
      'type': 'snack',
      'kcal': 220,
      'p': 25.0,
      'c': 24.0,
      'f': 2.0,
    },
  ];

  String _formatDate(DateTime d) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (isToday) return 'Bugün (${d.day} ${months[d.month - 1]})';
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final summaryAsync =
        ref.watch(dailyNutritionSummaryProvider(_selectedDate));

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(
                  dailyNutritionSummaryProvider(_selectedDate),
                );
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg,
                  SwanSpace.md,
                  SwanSpace.lg,
                  120,
                ),
                children: [
                  SwanPageHeader(
                    title: 'Beslenme ve Hidrasyon',
                    subtitle: 'Günlük kalori, makro ve su takibi',
                    onBack: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(height: SwanSpace.md),
                  _buildDateSelector(c),
                  const SizedBox(height: SwanSpace.lg),
                  summaryAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(SwanSpace.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                        border: Border.all(color: c.line),
                      ),
                      child: Text(
                        'Beslenme kayıtları yüklenemedi: $err',
                        style: SwanType.caption(c.danger),
                      ),
                    ),
                    data: (summary) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHydrationCard(c, summary, profile?.id),
                        const SizedBox(height: SwanSpace.lg),
                        _buildCalorieCard(c, summary),
                        const SizedBox(height: SwanSpace.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Öğün Günlüğü', style: SwanType.h3(c.ink)),
                            TextButton.icon(
                              onPressed: () => _openAddMealModal(
                                context: context,
                                c: c,
                                profileId: profile?.id,
                                initialType: 'snack',
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Besin Ekle'),
                              style: TextButton.styleFrom(
                                foregroundColor: c.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SwanSpace.xs),
                        _buildMealSection(
                          c: c,
                          title: 'Kahvaltı',
                          mealType: 'breakfast',
                          icon: Icons.wb_sunny_outlined,
                          logs: summary.logs
                              .where((l) => l.mealType == 'breakfast')
                              .toList(),
                          profileId: profile?.id,
                        ),
                        const SizedBox(height: SwanSpace.sm),
                        _buildMealSection(
                          c: c,
                          title: 'Öğle Yemeği',
                          mealType: 'lunch',
                          icon: Icons.lunch_dining_rounded,
                          logs: summary.logs
                              .where((l) => l.mealType == 'lunch')
                              .toList(),
                          profileId: profile?.id,
                        ),
                        const SizedBox(height: SwanSpace.sm),
                        _buildMealSection(
                          c: c,
                          title: 'Akşam Yemeği',
                          mealType: 'dinner',
                          icon: Icons.dinner_dining_rounded,
                          logs: summary.logs
                              .where((l) => l.mealType == 'dinner')
                              .toList(),
                          profileId: profile?.id,
                        ),
                        const SizedBox(height: SwanSpace.sm),
                        _buildMealSection(
                          c: c,
                          title: 'Ara Öğün & Takviye',
                          mealType: 'snack',
                          icon: Icons.local_cafe_outlined,
                          logs: summary.logs
                              .where((l) => l.mealType == 'snack')
                              .toList(),
                          profileId: profile?.id,
                        ),
                      ],
                    ),
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

  Widget _buildDateSelector(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SwanSpace.md,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: c.ink),
            onPressed: () {
              setState(() {
                _selectedDate =
                    _selectedDate.subtract(const Duration(days: 1));
              });
            },
            tooltip: 'Önceki gün',
          ),
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: c.accent),
              const SizedBox(width: SwanSpace.xs),
              Text(
                _formatDate(_selectedDate),
                style: SwanType.bodySm(c.ink, w: FontWeight.w700),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: c.ink),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
              });
            },
            tooltip: 'Sonraki gün',
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationCard(
    SwanPalette c,
    DailyNutritionSummary summary,
    String? profileId,
  ) {
    final progress =
        (summary.totalWaterMl / summary.targetWaterMl).clamp(0.0, 1.0);
    const waterBlue = Color(0xFF0284C7);

    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: waterBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: waterBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Günlük Hidrasyon',
                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                      ),
                      Text(
                        'Hedef: ${summary.targetWaterMl} ml',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${summary.totalWaterMl} ml',
                style: SwanType.h2(waterBlue),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: c.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(waterBlue),
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateWater(profileId, 250),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+250 ml (1 Bardak)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: waterBlue,
                    side: BorderSide(
                      color: waterBlue.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateWater(profileId, 500),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+500 ml (Şişe)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: waterBlue,
                    side: BorderSide(
                      color: waterBlue.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              IconButton(
                onPressed: summary.totalWaterMl > 0
                    ? () => _updateWater(profileId, -250)
                    : null,
                icon: const Icon(Icons.remove_rounded, size: 18),
                tooltip: '-250 ml azalt',
                color: c.inkMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateWater(String? profileId, int deltaMl) async {
    if (profileId == null) return;
    final athlete =
        await ref.read(athleteByProfileProvider(profileId).future);
    if (athlete == null) return;

    await ref.read(nutritionServiceProvider).logWater(
          athleteId: athlete.id,
          date: _selectedDate,
          deltaMl: deltaMl,
        );

    ref.invalidate(dailyNutritionSummaryProvider(_selectedDate));
  }

  Widget _buildCalorieCard(SwanPalette c, DailyNutritionSummary summary) {
    final calorieProgress =
        (summary.totalCalories / summary.targetCalories).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
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
                    'Kalori & Makro Dengesi',
                    style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${summary.totalCalories}',
                        style: SwanType.h1(c.accent),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ ${summary.targetCalories} kcal',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '%${(calorieProgress * 100).round()} Tüketildi',
                  style: SwanType.caption(c.accent, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: calorieProgress,
              minHeight: 8,
              backgroundColor: c.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(c.accent),
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          Row(
            children: [
              Expanded(
                child: _buildMacroBox(
                  c: c,
                  label: 'Protein',
                  grams: summary.totalProtein,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              Expanded(
                child: _buildMacroBox(
                  c: c,
                  label: 'Karbonhidrat',
                  grams: summary.totalCarb,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              Expanded(
                child: _buildMacroBox(
                  c: c,
                  label: 'Yağ',
                  grams: summary.totalFat,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBox({
    required SwanPalette c,
    required String label,
    required double grams,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: SwanType.caption(c.inkMuted).copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${grams.toStringAsFixed(1)} g',
            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSection({
    required SwanPalette c,
    required String title,
    required String mealType,
    required IconData icon,
    required List<NutritionLog> logs,
    required String? profileId,
  }) {
    final totalCals =
        logs.fold<int>(0, (sum, item) => sum + item.calories);

    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: c.accent),
              const SizedBox(width: SwanSpace.xs),
              Expanded(
                child: Text(
                  title,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                ),
              ),
              Text(
                '$totalCals kcal',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                onPressed: () => _openAddMealModal(
                  context: context,
                  c: c,
                  profileId: profileId,
                  initialType: mealType,
                ),
                tooltip: '$title için besin ekle',
                color: c.accent,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: SwanSpace.xs),
            Divider(color: c.line, height: 1),
            const SizedBox(height: SwanSpace.xs),
            ...logs.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                          ),
                          Text(
                            '${item.calories} kcal · P: ${item.proteinG.round()}g · K: ${item.carbG.round()}g · Y: ${item.fatG.round()}g',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () async {
                        await ref
                            .read(nutritionServiceProvider)
                            .deleteLog(item.id);
                        ref.invalidate(
                          dailyNutritionSummaryProvider(_selectedDate),
                        );
                      },
                      tooltip: 'Kaydı sil',
                      color: c.inkMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAddMealModal({
    required BuildContext context,
    required SwanPalette c,
    required String? profileId,
    required String initialType,
  }) async {
    if (profileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt için sporcu profili gereklidir.')),
      );
      return;
    }
    final athlete =
        await ref.read(athleteByProfileProvider(profileId).future);
    if (athlete == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sporcu profili bulunamadı.')),
      );
      return;
    }

    final titleController = TextEditingController();
    final calController = TextEditingController();
    final pController = TextEditingController();
    final cController = TextEditingController();
    final fController = TextEditingController();
    String selectedType = initialType;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                SwanSpace.lg,
                SwanSpace.lg,
                SwanSpace.lg,
                MediaQuery.of(ctx).viewInsets.bottom + SwanSpace.xl,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: SwanSpace.md),
                    Text('Öğüne Besin Ekle', style: SwanType.h2(c.ink)),
                    const SizedBox(height: SwanSpace.sm),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Öğün Türü',
                        labelStyle: SwanType.caption(c.inkMuted),
                        filled: true,
                        fillColor: c.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                      ),
                      dropdownColor: c.surface,
                      items: const [
                        DropdownMenuItem(
                          value: 'breakfast',
                          child: Text('Kahvaltı'),
                        ),
                        DropdownMenuItem(
                          value: 'lunch',
                          child: Text('Öğle Yemeği'),
                        ),
                        DropdownMenuItem(
                          value: 'dinner',
                          child: Text('Akşam Yemeği'),
                        ),
                        DropdownMenuItem(
                          value: 'snack',
                          child: Text('Ara Öğün & Takviye'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: SwanSpace.md),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Besin / Yemek Adı',
                        hintText: 'örn. Izgara Somon & Fırın Patates',
                        labelStyle: SwanType.caption(c.inkMuted),
                        hintStyle: SwanType.caption(c.inkMuted),
                        filled: true,
                        fillColor: c.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                      ),
                      style: SwanType.bodySm(c.ink),
                    ),
                    const SizedBox(height: SwanSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: calController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Kalori (kcal)',
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                        const SizedBox(width: SwanSpace.xs),
                        Expanded(
                          child: TextField(
                            controller: pController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Protein (g)',
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SwanSpace.xs),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Karb (g)',
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                        const SizedBox(width: SwanSpace.xs),
                        Expanded(
                          child: TextField(
                            controller: fController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Yağ (g)',
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SwanSpace.md),
                    Text(
                      'Hızlı Şablonlar:',
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                    ),
                    const SizedBox(height: SwanSpace.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickSuggestions.map((sug) {
                        return ActionChip(
                          label: Text(sug['title'] as String),
                          labelStyle: SwanType.caption(c.ink),
                          backgroundColor: c.surfaceAlt,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: c.line),
                          ),
                          onPressed: () {
                            setModalState(() {
                              titleController.text = sug['title'] as String;
                              selectedType = sug['type'] as String;
                              calController.text = sug['kcal'].toString();
                              pController.text = sug['p'].toString();
                              cController.text = sug['c'].toString();
                              fController.text = sug['f'].toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: SwanSpace.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final title = titleController.text.trim();
                                if (title.isEmpty) return;
                                final kcal =
                                    int.tryParse(calController.text.trim()) ??
                                        0;
                                final p =
                                    double.tryParse(pController.text.trim()) ??
                                        0.0;
                                final carb =
                                    double.tryParse(cController.text.trim()) ??
                                        0.0;
                                final fat =
                                    double.tryParse(fController.text.trim()) ??
                                        0.0;

                                setModalState(() => isSaving = true);
                                try {
                                  await ref
                                      .read(nutritionServiceProvider)
                                      .addMeal(
                                        athleteId: athlete.id,
                                        date: _selectedDate,
                                        mealType: selectedType,
                                        title: title,
                                        calories: kcal,
                                        proteinG: p,
                                        carbG: carb,
                                        fatG: fat,
                                      );

                                  ref.invalidate(
                                    dailyNutritionSummaryProvider(
                                      _selectedDate,
                                    ),
                                  );

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Öğün kaydedildi.'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Kayıt başarısız: $e'),
                                        backgroundColor: c.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Kaydet',
                                style: SwanType.bodySm(
                                  Colors.white,
                                  w: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

