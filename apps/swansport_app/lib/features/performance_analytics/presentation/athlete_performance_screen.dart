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
                  if (ref.watch(
                    featureEnabledProvider(FeatureFlags.developmentReport),
                  ))
                    TextButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/gelisim-raporu',
                        arguments: {'id': widget.athleteId},
                      ),
                      icon: const Icon(Icons.insights_rounded),
                      label: const Text('Dönem gelişim raporu'),
                    ),
                  const SizedBox(height: 14),
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
